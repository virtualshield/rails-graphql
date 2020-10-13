# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Request
    #
    # This class is responsible for processing a GraphQL response. It will
    # handle queries, mutations, and subscription, as long as all of them are
    # provided together. It also can be executed multiple times using the same
    # context calling +execute+ multiple times.
    #
    # ==== Options
    #
    # * <tt>:namespace</tt> - Set what is the namespace used for the request
    #   (defaults to :base).
    class Request
      extend ActiveSupport::Autoload

      RESPONSE_FORMATS = { string: :to_s, object: :to_h, hash: :to_h }.freeze

      eager_autoload do
        autoload_under :steps do
          autoload :Organizable
          autoload :Prepareable
          autoload :Resolveable
        end

        autoload_under :helpers do
          autoload :Directives
          autoload :SelectionSet
          autoload :ValueWriters
        end

        autoload :Arguments
        autoload :Component
        autoload :Context
        autoload :Errors
        autoload :Event
        autoload :Strategy
      end

      attr_reader :schema, :visitor, :operations, :fragments, :errors,
        :args, :response, :strategy, :stack

      delegate :all_listeners, to: :schema

      class << self
        # Shortcut for initialize, set context, and execute
        def execute(*args, schema: nil, namespace: :base, context: {}, **xargs)
          result = new(schema, namespace: namespace)
          result.context = context if context.present?
          result.execute(*args, **xargs)
        end

        # Allow accessing component-based objects through the request
        def const_defined?(name, *)
          Component.const_defined?(name) || super
        end

        # Allow accessing component-based objects through the request
        def const_missing(name)
          Component.const_defined?(name) ? Component.const_get(name) : super
        end

        def eager_load! # :nodoc:
          super

          Request::Component.eager_load!
          Request::Strategy.eager_load!
        end
      end

      # Forces the schema to be registered on type map before moving forward
      def initialize(schema = nil, namespace: :base)
        @namespace = schema&.namespace || namespace
        @schema = GraphQL::Schema.find!(@namespace)
        @extensions = {}

        ensure_schema!
      end

      # Cache all the schema events for this current request
      def all_events
        @all_events ||= schema.all_events
      end

      # Get the context of the request
      def context
        @context ||= OpenStruct.new.freeze
      end

      # Set the context of the request, it must be a +Hash+
      def context=(data)
        @context = build_ostruct(data).freeze
      end

      # Execute a given document with the given arguments
      def execute(document, as: :string, **xargs)
        reset!(**xargs)

        to = RESPONSE_FORMATS[as]
        @response = initialize_response(as, to)

        execute!(document)
        response.public_send(to)
      end

      alias perform execute

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
        schema.rescue_with_handler(exception, object: build_rescue_object(**extra))
      end

      # Add the given +exception+ to the errors using the +node+ location
      def exception_to_error(exception, node, **xargs)
        xargs[:exception] = exception.class.name
        report_node_error(exception.message, node, **xargs)
      end

      # A little helper to report an error on a given node
      def report_node_error(message, node, **xargs)
        location = GraphQL::Native.get_location(node)
        xargs[:col] ||= location.begin_column
        xargs[:line] ||= location.begin_line
        report_error(message, **xargs)
      end

      # The final helper that facilitates how errors are reported
      def report_error(message, **xargs)
        xargs[:path] ||= stack_to_path
        errors.add(message, **xargs)
      end

      # Add the given +object+ into the execution +stack+ and execute the given
      # +block+ making sure to rescue exceptions using the +rescue_with_handler+
      def stacked(object, &block)
        stack.unshift(object)
        block.call
      rescue => exception
        rescue_with_handler(exception) || raise
      ensure
        stack.shift
      end

      # Convert the current stack into a error path ignoring the schema
      def stack_to_path
        stack[0..-2].map do |item|
          item.is_a?(Numeric) ? item : item.try(:gql_name)
        end.compact.reverse
      end

      # Add extensions to the request, which ensures a bunch of extended
      # behaviors for all the objects created through the request
      def extend(*modules)
        import_extensions(*modules)
        request_ext = extensions[self.class]
        super(request_ext) if request_ext && !is_a?(request_ext)
      end

      # This initiates a new object which is aware of extensions
      def build(klass, *args, &block)
        ext_module = extensions[klass]
        obj = klass.new(*args, &block)
        obj.extend(ext_module) if ext_module
        obj
      end

      # Get and cache a sanitized version of the arguments
      def sanitized_arguments
        return {} unless args.each_pair.any?
        cache(:sanitized_arguments) do
          args.to_h.transform_keys { |key| key.to_s.camelize(:lower) }
        end
      end

      # A shared way to cache information across the execution of an request
      def cache(key, init_value = nil, &block)
        @cache[key] ||= (init_value || block&.call || {})
      end

      private
        attr_reader :extensions

        # Reset principal variables and set the given +args+
        def reset!(args: nil, variables: {}, operation_name: nil)
          @args    = build_ostruct(args || variables).freeze
          @errors  = Request::Errors.new(self)
          @visitor = GraphQL::Native::Visitor.new
          @operation_name = operation_name

          @stack      = [schema]
          @cache      = {}
          @fragments  = {}
          @operations = {}
        end

        # This executes the whole process capturing any exceptions and handling
        # them as defined by the schema
        def execute!(document)
          log_execution(document) do
            @document = GraphQL::Native.parse(document)
            collect_definitions!

            @strategy = find_strategy!
            @strategy.trigger_event(:request)
            @strategy.resolve!
          end
        rescue ParseError => err
          parts = err.message.match(/\A(\d+)\.(\d+)(?:-\d+)?: (.*)\z/)
          errors.add(parts[3], line: parts[1], col: parts[2])
        ensure
          @cache.clear
          @fragments.clear
          @operations.clear

          @visitor.terminate
          @visitor = nil

          GraphQL::Native.free_node(@document)
          @response.try(:append_errors, errors)
        end

        # Use the visitor to collect the operations and fragments
        def collect_definitions!
          visitor.collect_definitions(@document) do |kind, node, data|
            case kind
            when :operation
              operations[data[:name]] = Component::Operation.build(self, node, data)
            when :fragment
              fragments[data[:name]] = build(Component::Fragment, self, node, data)
            end
          end
        end

        # Find the best strategy to resolve the request
        def find_strategy!
          klass = schema.config.request_strategies.lazy.map do |klass_name|
            klass_name.constantize
          end.select do |klass|
            klass.can_resolve?(self)
          end.max_by(&:priority)
          build(klass, self)
        end

        # Find all necessary extensions inside the given +modules+ and prepare
        # the extension base module
        def import_extensions(*modules)
          modules.each do |mod|
            mod.constants.each do |const_name|
              const_name = const_name.to_s
              const = mod.const_get(const_name)
              next unless const.is_a?(Module)

              # Find the related request class to extend
              klass = const_name === 'Request' ? self.class : begin
                const_name.split('_').inject(self.class) do |klass, next_const|
                  klass.const_defined?(next_const) ? klass.const_get(next_const) : break
                end
              end

              # Create the shared module and include the extension
              next unless klass&.is_a?(Class)
              extensions[klass] ||= Module.new
              extensions[klass].include(const)
            end
          end
        end

        # Log the execution of a GraphQL document
        def log_execution(document)
          ActiveSupport::Notifications.instrument('request.graphql') do |payload|
            yield.tap { log_payload(document, payload) }
          end
        end

        # Build the payload to be sent to the log
        def log_payload(document, data)
          name = @operation_name.presence
          name ||= operations.keys.first if operations.size.eql?(1)
          map_variables = args.to_h if args.each_pair.any?

          data.merge!(
            name: name,
            cached: false,
            document: document,
            variables: map_variables,
          )
        end

        # Initialize the class that responsible for storaging the response
        def initialize_response(as, to)
          raise ::ArgumentError, <<~MSG.squish if to.nil?
            The given format #{as.inspect} is not a valid reponse format.
          MSG

          klass = schema.config.enable_string_collector \
            ? Collectors::JsonCollector \
            : Collectors::HashCollector

          obj = klass.new(self)
          raise ::ArgumentError, <<~MSG.squish unless obj.respond_to?(to)
            Unable to use "#{klass.name}" as response collector since it does
            not implement a #{to.inspect} method.
          MSG

          obj
        end

        # Little helper to build an +OpenStruct+ ensure the given +value+ is a
        # +Hash+. It can also +transform_keys+ with the given block
        def build_ostruct(value, &block)
          raise ::ArgumentError, <<~MSG.squish unless value.kind_of?(Hash)
            The "#{value.class.name}" is not a valid hash.
          MSG

          value = value.deep_transform_keys(&block) if block.present?
          OpenStruct.new(value)
        end

        # Make sure that a schema was assigned by find the corresponding one for
        # the namespace of the request
        def ensure_schema!
          raise ::ArgumentError, <<~MSG.squish if schema.nil?
            Unable to perform a request under the #{@namespace.inspect} namespace,
            because there are no schema assigned to it.
          MSG
        end
    end
  end
end
