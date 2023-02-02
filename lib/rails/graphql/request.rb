# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Request
    #
    # This class is responsible for processing a GraphQL response. It will
    # handle queries, mutations, and subscription, as long as all of them are
    # provided together. It also can be executed multiple times using the same
    # context calling +execute+ multiple times.
    #
    # ==== Options
    #
    # * <tt>:args</tt> - The arguments of the request, same as variables
    # * <tt>:as</tt> - The format of the output of the request, supports both
    #   +:hash+ and +:string+ (defaults to :string)
    # * <tt>:context</tt> - The context of the request, which can be accessed in
    #   fields, resolvers and so as a way to customize the result
    # * <tt>:controller</tt> - From which controller this operation is running
    #   from, which provides view-like access to helpers and methods through the
    #   request
    # * <tt>:namespace</tt> - Set what is the namespace used for the request
    #   (defaults to :base)
    # * <tt>:operation_name</tt> - The name of the operation as a sort of label,
    #   it can also be collected by the name of the single operation in the
    #   request
    # * <tt>:schema</tt> - The schema on which the request should run on. It
    #   has higher precedence than the namespace
    # * <tt>:variables</tt> - The variables of the request
    class Request
      extend ActiveSupport::Autoload

      RESPONSE_FORMATS = {
        string: :to_json,
        object: :as_json,
        json: :as_json,
        hash: :as_json,
      }.freeze

      eager_autoload do
        autoload_under :steps do
          autoload :Authorizable
          autoload :Organizable
          autoload :Preparable
          autoload :Resolvable
        end

        autoload_under :helpers do
          autoload :Directives
          autoload :SelectionSet
          autoload :ValueWriters
        end

        autoload :Arguments
        autoload :Backtrace
        autoload :Component
        autoload :Context
        autoload :Errors
        autoload :Event
        autoload :PreparedData
        autoload :Strategy
        autoload :Subscription
      end

      attr_reader :args, :origin, :errors, :fragments, :operations, :response, :schema,
        :stack, :strategy, :document, :operation_name, :subscriptions

      alias arguments args
      alias controller origin
      alias channel origin

      delegate :action_name, to: :controller, allow_nil: true
      delegate :find_type!, to: :strategy, allow_nil: true
      delegate :all_listeners, :all_events, to: :schema

      alias find_type find_type!

      class << self
        # Shortcut for initialize, set context, and execute
        def execute(*args, schema: nil, namespace: :base, context: {}, **xargs)
          result = new(schema, namespace: namespace)
          result.context = context if context.present?
          result.execute(*args, **xargs)
        end

        # Shortcut for initialize and compile
        def compile(*args, schema: nil, namespace: :base, **xargs)
          new(schema, namespace: namespace).compile(*args, **xargs)
        end

        # Shortcut for initialize and validate
        def valid?(*args, schema: nil, namespace: :base, **xargs)
          new(schema, namespace: namespace).valid?(*args, **xargs)
        end

        # Allow accessing component-based objects through the request
        def const_defined?(name, *)
          Component.const_defined?(name) || super
        end

        # Allow accessing component-based objects through the request
        def const_missing(name)
          Component.const_defined?(name) ? Component.const_get(name) : super
        end
      end

      # Forces the schema to be registered on type map before moving forward
      def initialize(schema = nil, namespace: :base)
        @namespace = schema&.namespace || namespace
        @schema = GraphQL::Schema.find!(@namespace)

        ensure_schema!
      end

      # Check if any new subscription was added
      def subscriptions?
        defined?(@subscriptions) && @subscriptions.any?
      end

      # Get the context of the request
      def context
        @context ||= OpenStruct.new.freeze
      end

      # Set the context of the request, it must be a +Hash+
      def context=(data)
        @context = build_ostruct(data).freeze
      end

      # Allow adding extra information to the response, in a extensions key
      def extensions
        @extensions ||= {}
      end

      # Execute a given document with the given arguments
      def execute(document, **xargs)
        output = xargs.delete(:as) || schema.config.default_response_format
        cache = xargs.delete(:hash)
        formatter = RESPONSE_FORMATS[output]

        document, cache = nil, document if xargs.delete(:compiled)
        prepared_data = xargs.delete(:data_for)
        reset!(**xargs)

        @response = initialize_response(output, formatter)
        import_prepared_data(prepared_data)
        execute!(document, cache)

        response.public_send(formatter)
      rescue StaticResponse
        response.public_send(formatter)
      end

      alias perform execute

      # Compile a given document
      def compile(document, compress: true)
        reset!

        log_execution(document, event: 'compile.graphql') do
          @document = initialize_document(document)
          run_document(with: :compile)

          result = Marshal.dump(cache_dump)
          result = Zlib.deflate(result) if compress

          @log_extra[:total] = result.bytesize
          result
        end
      end

      # Check if the given document is valid by piggybacking on the compile
      # process
      def valid?(document)
        reset!

        log_execution(document, event: 'validate.graphql') do
          @document = initialize_document(document)
          run_document(with: :compile)
          @log_extra[:result] = @errors.empty?
        end
      end

      # This is used by cache and static responses to jump from executing to
      # delivery a response right away
      def force_response(response, error = StaticResponse)
        @response = response
        raise error
      end

      # Import prepared data that is formatted as a hash
      def import_prepared_data(prepared_data)
        prepared_data&.each do |key, value|
          prepare_data_for(key, value)
        end
      end

      # Add a new prepared data from +value+ to the given +field+
      def prepare_data_for(field, value, **options)
        field = PreparedData.lookup(self, field)

        if prepared_data.key?(field)
          prepared_data[field].push(value)
        else
          prepared_data[field] = PreparedData.new(field, value, **options)
        end
      end

      # Recover the next prepared data for the given field
      def prepared_data_for(field)
        return unless defined?(@prepared_data)

        field = field.field if field.is_a?(Component::Field)
        prepared_data[field]
      end

      # Check if the given field has prepared data
      def prepared_data_for?(field)
        return false unless defined?(@prepared_data)

        field = field.field if field.is_a?(Component::Field)
        prepared_data.key?(field)
      end

      # Build a easy-to-access object representing the current information of
      # the execution to be used on +rescue_with_handler+
      def build_rescue_object(**extra)
        OpenStruct.new(extra.reverse_merge(
          args: @args,
          source: stack.first,
          request: self,
          response: @response,
          document: @document,
        )).freeze
      end

      # Use schema handlers for exceptions caught during the execution process
      def rescue_with_handler(exception, **extra)
        ExtendedError.extend(exception, build_rescue_object(**extra))
        schema.rescue_with_handler(exception)
      end

      # Add the given +exception+ to the errors using the +node+ location
      def exception_to_error(exception, node, **xargs)
        xargs[:exception] = exception.class.name
        report_node_error(xargs.delete(:message) || exception.message, node, **xargs)
      end

      # A little helper to report an error on a given node
      def report_node_error(message, node, **xargs)
        xargs[:locations] ||= location_of(node) unless xargs.key?(:line)
        report_error(message, **xargs)
      end

      # Get the location object of a given node
      def location_of(node)
        node = node.instance_variable_get(:@node) if node.is_a?(Request::Component)
        return unless node.is_a?(GQLParser::Token)

        [
          { 'line' => node.begin_line, 'column' => node.begin_column },
          { 'line' => node.end_line,   'column' => node.end_column },
        ]
      end

      # The final helper that facilitates how errors are reported
      def report_error(message, **xargs)
        xargs[:path] ||= stack_to_path
        errors.add(message, **xargs)

        nil # Return nil for easier usage
      end

      # Add the given +object+ into the execution +stack+ and execute the given
      # +block+ making sure to rescue exceptions using the +rescue_with_handler+
      def stacked(object, &block)
        stack.unshift(object)
        block.call
      ensure
        stack.shift
      end

      # Convert the current stack into a error path ignoring the schema
      def stack_to_path
        stack[0..-2].map do |item|
          item.is_a?(Numeric) ? item : item.try(:gql_name)
        end.compact.reverse
      end

      # Add class extensions to the request, which ensures a bunch of
      # extended behaviors for all the objects created through the request
      def extend(*modules)
        import_class_extensions(*modules)
        request_ext = class_extensions[self.class]
        super(request_ext) if request_ext && !is_a?(request_ext)
      end

      # This initiates a new object which is aware of class extensions
      def build(klass, *args, &block)
        ext_module = class_extensions[klass]
        obj = klass.new(*args, &block)
        obj.extend(ext_module) if ext_module
        obj
      end

      # This allocates a new object which is aware of class extensions
      def build_from_cache(klass)
        ext_module = class_extensions[klass]
        obj = klass.allocate
        obj.extend(ext_module) if ext_module
        obj
      end

      # A shared way to cache information across the execution of an request
      def cache(key, init_value = nil, &block)
        @cache[key] ||= (init_value || block&.call || {})
      end

      # A better way to ensure that nil values in a hash cache won't be
      # reinitialized
      def nested_cache(key, sub_key)
        (source = cache(key)).key?(sub_key) ? source[sub_key] : source[sub_key] = yield
      end

      # Show if the current cached operation is still valid
      def valid_cache?
        defined?(@valid_cache) && @valid_cache
      end

      # Write the request into the cache so it can run again faster
      def write_cache_request(hash, data = cache_dump)
        schema.write_on_cache(hash, Marshal.dump(data))
      end

      # Read the request from the cache to run it faster
      def read_cache_request(data = @document)
        begin
          data = Zlib.inflate(data) if data[0] == 'x'
          data = Marshal.load(data)
        rescue Zlib::BufError, ArgumentError
          raise ::ArgumentError, +'Unable to recover the cached request.'
        end

        cache_load(data)
      end

      # Build the object that represent the request in the cache format
      def cache_dump
        {
          strategy: @strategy.cache_dump,
          operation_name: @operation_name,
          type_map_version: schema.version,
          document: @document,
          errors: @errors.cache_dump,
          operations: @operations.transform_values(&:cache_dump),
          fragments: @fragments&.transform_values { |f| f.try(:cache_dump) }&.compact,
        }
      end

      # Read the request from the cache to run it faster
      def cache_load(data)
        version = data[:type_map_version]
        @document = data[:document]
        @operation_name = data[:operation_name]
        resolve_from_cache = (version == schema.version)

        # Run the document from scratch if TypeMap has changed
        return run_document unless resolve_from_cache
        @valid_cache = true unless defined?(@valid_cache)

        # Run the document as a cached operation
        errors.cache_load(data[:errors])
        @strategy = build(data[:strategy][:class], self)
        @strategy.trigger_event(:request)
        @strategy.cache_load(data)
        @strategy.resolve!
      end

      protected

        # Stores all the class extensions
        def class_extensions
          @class_extensions ||= {}
        end

        # Stores all the prepared data, but only when it is needed
        def prepared_data
          @prepared_data ||= {}
        end

      private

        # Reset principal variables and set the given +args+
        def reset!(args: nil, variables: {}, operation_name: nil, origin: nil)
          @arg_names = {}

          @args = (args || variables || {}).transform_keys do |key|
            key.to_s.camelize(:lower).tap do |sanitized_key|
              @arg_names[sanitized_key] = key
            end
          end

          @args = build_ostruct(@args).freeze
          @errors = Request::Errors.new(self)
          @operation_name = operation_name
          @origin = origin

          @stack      = [schema]
          @cache      = {}
          @log_extra  = {}
          @subscriptions = {}
          @used_variables = Set.new

          @strategy = nil
          schema.validate
        end

        # This executes the whole process capturing any exceptions and handling
        # them as defined by the schema
        def execute!(document, cache = nil)
          log_execution(document, cache) do
            @document = initialize_document(document, cache)
            @document.is_a?(String) ? read_cache_request : run_document
          end
        ensure
          report_unused_variables
          write_cache_request(cache) if cache.present? && !valid_cache?
          @response.try(:append_errors, errors)

          if defined?(@extensions)
            @response.try(:append_extensions, @extensions)
            @extensions.clear
          end

          @cache.clear
          @strategy&.clear
          @fragments&.clear
          @operations&.clear
          @prepared_data&.clear
        end

        # Prepare the definitions, find the strategy and resolve
        def run_document(with: :resolve!)
          return if @document.nil?

          collect_definitions!
          @strategy ||= find_strategy!
          @strategy.trigger_event(:request)
          @strategy.public_send(with)
        end

        # Organize the list of definitions from the document
        def collect_definitions!
          @operations = @document[0]&.index_by { |node| node[1] }
          @fragments = @document[1]&.index_by { |node| node[0] }

          raise ::ArgumentError, (+<<~MSG).squish if operations.blank?
            The document does not contains operations.
          MSG
        end

        # Find the best strategy to resolve the request
        def find_strategy!
          klass = schema.config.request_strategies.lazy.map(&:constantize).select do |k|
            k.can_resolve?(self)
          end.max_by(&:priority)
          build(klass, self)
        end

        # Find all necessary class extensions inside the given +modules+
        # and prepare the extension base module
        def import_class_extensions(*modules)
          modules.each do |mod|
            mod.constants.each do |const_name|
              const_name = const_name.to_s
              const = mod.const_get(const_name)
              next unless const.is_a?(Module)

              # Find the related request class to extend
              klass = const_name === 'Request' ? self.class : begin
                const_name.split('_').inject(self.class) do |k, next_const|
                  k.const_defined?(next_const) ? k.const_get(next_const) : break
                end
              end

              # Create the shared module and include the class extension
              next unless klass&.is_a?(Class)
              class_extensions[klass] ||= Module.new
              class_extensions[klass].include(const)
            end
          end
        end

        # Log the execution of a GraphQL document
        def log_execution(document, hash = nil, event: 'request.graphql')
          return yield if event.nil?

          data = { document: document, hash: hash }
          ActiveSupport::Notifications.instrument(event, **data) do |payload|
            yield.tap { log_payload(payload) }
          end
        end

        # Build the payload to be sent to the log
        def log_payload(data)
          name = @operation_name.presence
          name ||= operations.keys.first if operations&.size&.eql?(1)
          map_variables = args.to_h.transform_keys do |key|
            @arg_names[key.to_s]
          end

          data.merge!(@log_extra)
          data.merge!(
            name: name,
            cached: false,
            variables: map_variables.presence,
          )
        end

        # When document is empty and the hash has been provided, then
        def initialize_document(document, cache = nil)
          if document.present?
            ::GQLParser.parse_execution(document)
          elsif cache.nil?
            raise ::ArgumentError, +'Unable to execute an empty document.'
          elsif schema.cached?(cache)
            schema.read_from_cache(cache)
          else
            @valid_cache = true
            cache
          end
        rescue ::GQLParser::ParserError => err
          parts = err.message.match(/\A(Parser error: .*) at \[(\d+), (\d+)\]\z/m)
          errors.add(parts[1], line: parts[2].to_i, col: parts[3].to_i)
          nil
        end

        # Initialize the class that responsible for storing the response
        def initialize_response(as_format, to)
          raise ::ArgumentError, (+<<~MSG).squish if to.nil?
            The given format #{as_format.inspect} is not a valid response format.
          MSG

          klass =
            if schema.config.enable_string_collector && as_format == :string
              Collectors::JsonCollector
            elsif RESPONSE_FORMATS.key?(as_format)
              Collectors::HashCollector
            else
              as_format
            end

          obj = klass.new(self)
          raise ::ArgumentError, (+<<~MSG).squish unless obj.respond_to?(to)
            Unable to use "#{klass.name}" as response collector since it does
            not implement a #{to.inspect} method.
          MSG

          obj
        end

        # Little helper to build an +OpenStruct+ ensure the given +value+ is a
        # +Hash+. It can also +transform_keys+ with the given block
        def build_ostruct(value, &block)
          raise ::ArgumentError, (+<<~MSG).squish unless value.is_a?(::Hash)
            The "#{value.class.name}" is not a valid hash.
          MSG

          value = value.deep_transform_keys(&block) if block.present?
          OpenStruct.new(value)
        end

        # Make sure that a schema was assigned by find the corresponding one for
        # the namespace of the request
        def ensure_schema!
          raise ::ArgumentError, (+<<~MSG).squish if schema.nil?
            Unable to perform a request under the #{@namespace.inspect} namespace,
            because there are no schema assigned to it.
          MSG
        end

        # Check all the operations and report any provided variable that was not
        # used
        def report_unused_variables
          (@arg_names.keys - @used_variables.to_a).each do |key|
            errors.add((+<<~MSG).squish)
              Variable $#{@arg_names[key]} was provided but not used.
            MSG
          end
        end
    end
  end
end
