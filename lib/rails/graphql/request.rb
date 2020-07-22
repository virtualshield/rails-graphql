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
          autoload :Resolveable
        end

        autoload_under :helpers do
          autoload :Directives
          autoload :SelectionSet
        end

        autoload_under :extensions do
          autoload :Debugger
        end

        autoload :Arguments
        autoload :Component
        autoload :Context
        autoload :Errors
        autoload :Event
        autoload :Strategy
      end

      ##
      # :singleton-method:
      # A list of execution strategies. Each application can add their own by
      # simply append a class name, preferable as string, in this list.
      mattr_accessor :strategies, instance_writer: false, default: [
        'Rails::GraphQL::Request::Strategy::MultiQueryStrategy',
        'Rails::GraphQL::Request::Strategy::SequencedStrategy',
      ]

      attr_reader :schema, :visitor, :operations, :fragments, :errors,
        :args, :response, :strategy, :stack

      # Shortcut for initialize, set context, and execute
      def self.execute(*args, namespace: :base, context: {}, **xargs)
        result = new(namespace: namespace)
        result.context = context if context.present?
        result.execute(*args, **xargs)
      end

      # Shortcut for initialize, set context, and debug
      def self.debug(*args, namespace: :base, context: {}, **xargs)
        result = new(namespace: namespace)
        result.context = context if context.present?
        result.debug(*args, **xargs)
      end

      def initialize(schema = nil, namespace: :base)
        @namespace = schema&.namespace || namespace
        @schema = schema || GraphQL::Schema.find(namespace)
        @extensions = {}

        ensure_schema!
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
      def execute(document, args: {}, as: :string, **xargs)
        reset!(args)

        to = RESPONSE_FORMATS[as]
        @response = initialize_response(as, to)

        execute!(document)
        response.public_send(to)
      end

      # Add the debug extension to the resquest and then normally execute
      def debug(*args, **xargs)
        extend(Request::Debugger)
        execute(*args, **xargs)
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

      # Add the given +exception+ to the errors using the +node+ location.
      def exception_to_error(exception, node, **xargs)
        location = GraphQL::Native.get_location(node)
        xargs[:col] = location.begin_column
        xargs[:line] = location.begin_line
        xargs[:path] ||= stack_to_path

        xargs[:exception] = exception.class.name

        errors.add(exception.message, **xargs)
      end

      # Convert the current stack into a error path ignoring the schema
      def stack_to_path
        stack.map do |item|
          next item if item.is_a?(Numeric)
          item.try(:gql_name)
        end.compact
      end

      # Build a easy-to-access object representing the current information of
      # the execution to be used on +rescue_with_handler+.
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
      def rescue_with_handler(exception, **extra) # :nodoc:
        schema.rescue_with_handler(exception, object: build_rescue_object(**extra))
      end

      alias perform execute

      # Add extensions to the request, which ensures a bunch of extended
      # behaviors for all the objects created through the request
      def extend(*modules)
        import_extensions(*modules)
        request_ext = extensions[self.class]
        super(request_ext) if request_ext && !is_a?(request_ext)
      end

      # This initiates a new object which is aware of extensions
      def build(klass, *args, **xargs, &block)
        ext_module = extensions[klass]
        obj = klass.new(*args, **xargs, &block)
        obj.extend(ext_module) if ext_module
        obj
      end

      private
        attr_reader :extensions

        # Reset principal variables and set the given +args+
        def reset!(args)
          @args    = build_ostruct(args).freeze
          @errors  = Request::Errors.new(self)
          @visitor = GraphQL::Native::Visitor.new

          @stack      = [schema]
          @fragments  = {}
          @operations = {}
        end

        # This executes the whole process capturing any exceptions and handling
        # them as defined by the schema.
        def execute!(document)
          @document = GraphQL::Native.parse(document)
          collect_definitions!

          @strategy = find_strategy!
          @strategy.trigger_event(:request)
          @strategy.resolve!
        rescue ParseError => err
          parts = err.message.match(/\A(\d+)\.(\d+)(?:-\d+)?: (.*)\z/)
          errors.add(parts[3], line: parts[1], col: parts[2])
        ensure
          @response.try(:append_errors, errors)
        end

        # Use the visitor to collect the operations and fragments.
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

        # Find the best strategy to resolve the request.
        def find_strategy!
          klasss = strategies.lazy.map do |klass_name|
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

              klass = const_name === 'Request' ? self.class : begin
                const_name.split('_').inject(self.class) do |klass, next_const|
                  klass.const_defined?(next_const) ? klass.const_get(next_const) : break
                end
              end

              next unless klass&.is_a?(Class)
              extensions[klass] ||= Module.new
              extensions[klass].include(const)
            end
          end
        end

        # Initialize the class that responsible for storaging the response
        def initialize_response(as, to)
          raise ::ArgumentError, <<~MSG.squish if to.nil?
            The given format #{as.inspect} is not a valid reponse format.
          MSG

          # TODO: Fix the +enable_response_collector+, because it must be a
          # schema configuration.
          klass = GraphQL::Core.enable_response_collector \
            ? Collectors::JsonCollector \
            : Collectors::HashCollector

          obj = klass.new(self)
          raise ::ArgumentError, <<~MSG.squish unless obj.respond_to?(to)
            Unable to use "#{klass.name}" as response collector since it does
            not implement a #{to.inspect} method.
          MSG

          obj
        end

        # Little helper to build an +OpenStruct+ that has the correct underscore
        # keys
        def build_ostruct(hash)
          raise ::ArgumentError, <<~MSG.squish unless hash.kind_of?(Hash)
            The "#{hash.class.name}" is not a valid hash.
          MSG

          OpenStruct.new(hash.transform_keys { |key| key.to_s.underscore })
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
