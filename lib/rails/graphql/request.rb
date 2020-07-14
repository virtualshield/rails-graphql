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
        autoload :Argument
        autoload :Errors
        autoload :Field
        autoload :Fragment
        autoload :Operation
        autoload :Strategy

        autoload :Directives
        autoload :SelectionSet
      end

      ##
      # :singleton-method:
      # A list of execution strategies. Each application can add their own by
      # simply append a class name, preferable as string, in this list.
      mattr_accessor :strategies, instance_writer: false, default: [
        'Rails::GraphQL::Request::Strategy::MultiQueryStrategy',
        'Rails::GraphQL::Request::Strategy::SequencedStrategy',
      ]

      attr_reader :memo, :schema, :visitor, :stack, :operations, :fragments,
        :errors, :args, :response

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
      def execute(document, args = {}, as: :string, **xargs)
        reset!(args)

        to = RESPONSE_FORMATS[as]
        @response = initialize_response(as, to)

        execute!(document)
        @response.public_send(to)
      end

      # Debug a given document to an IO
      def debug(document, args = {}, to: $stdout)
        reset!(args)

        @response = Collectors::IdentedCollector.new(auto_eol: false)
        execute!(document, mode: :debug!)

        to.puts response.value
      end

      # Trigger an event using the +stack+ as the +objects+ for the
      # {+trigger_all+}[rdoc-ref:Rails::GraphQL::Event#trigger_all].
      def trigger_event(event_name, **xargs, &block)
        xargs[:all] = true
        xargs[:request] = self
        Event.trigger(stack, event_name, stack.first, :execution, **xargs, &block)
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
        # TODO: Use rails stack filter to add the error stack

        errors.add(exception.message, **xargs)
      end

      # Convert the current stack into a error path ignoring the schema
      def stack_to_path
        stack.map { |item| item.try(:gql_name) }.compact
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

      private

        # Reset principal variables and set the given +args+
        def reset!(args)
          @memo    = OpenStruct.new
          @args    = build_ostruct(args).freeze
          @errors  = Request::Errors.new(self)
          @visitor = GraphQL::Native::Visitor.new

          @stack      = [schema]
          @fragments  = {}
          @operations = {}
        end

        # This executes the whole process capturing any exceptions and handling
        # them as defined by the schema.
        def execute!(document, mode: :resolve!)
          @document = GraphQL::Native.parse(document)
          trigger_event(:request)
          collect_definitions!

          @strategy = find_strategy!(mode.eql?(:debug!))
          @strategy.public_send(mode)
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
              operations[data[:name]] = Request::Operation.build(self, node, data)
            when :fragment
              fragments[data[:name]] = Request::Fragment.new(self, node, data)
            end
          end
        end

        # Find the best strategy to resolve the request.
        def find_strategy!(debug = false)
          if debug
            response.puts('Selecting strategy:')
            response.indent
          end

          strategy = strategies.lazy.map do |klass_name|
            klass_name.constantize
          end.select do |klass|
            result = klass.can_resolve?(self)
            next result unless debug

            response.puts("#{klass.name}[#{klass.priority}] is #{result ? 'a' : 'no'} match!")
            result
          end.max_by(&:priority).new(self)
          return strategy unless debug

          response.unindent
          response.puts("Selected: #{strategy.class.name}")
          response.eol

          strategy
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
