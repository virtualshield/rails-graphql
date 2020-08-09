# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Strategy
      #
      # This is the base class for the strategies of resolving a request.
      class Strategy
        extend ActiveSupport::Autoload

        autoload :DynamicInstance

        eager_autoload do
          autoload :SequencedStrategy
          autoload :MultiQueryStrategy
        end

        # The priority of the strategy
        class_attribute :priority, instance_accessor: false, default: 1

        delegate :operations, :errors, :response, :schema, to: :request

        attr_reader :listeners, :request, :context

        class << self
          # Check if the strategy can resolve the given +request+. By default,
          # strategies cannot resolve a request. Override this method with a
          # valid checker.
          def can_resolve?(_)
            false
          end
        end

        def initialize(request)
          @request = request
          collect_request_listeners
        end

        # Executes the strategy in the normal mode
        def resolve!
          raise NotImplementedError
        end

        # Find a given +type+ and store it on request cache
        def find_type!(type)
          request.cache(:types)[type] ||= schema.find_type!(type)
        end

        # Find a given +directive+ and store it on request cache
        def find_directive!(directive)
          request.cache(:directives)[directive] ||= schema.find_directive!(directive)
        end

        # Check if it's enabled to collect listeners
        def add_listeners?
          !listeners.frozen?
        end

        # Check if any listener were actually added
        def listeners?
          listeners.any?
        end

        # Check if any object is listening to a given +event_name+
        def listening_to?(event_name)
          listeners? && listeners.key?(event_name.to_sym)
        end

        # When running an stacked operation, make sure that the object was added
        # to the list of the listeners
        def stacked(object, &block)
          request.stacked(object, &block)
        end

        # Resolve a value for a given object, It uses the +args+ to prevent
        # problems with nil values.
        def resolve(field, *args, array: false, decorate: false, &block)
          data_for(args, field) if args.size.zero?
          args << Event.trigger(:resolve, field, self, &field.resolver) \
            if field.try(:dynamic_resolver?)

          # Now we have a value to set on the context
          value = args.last
          value = field.decorate(value) if decorate
          @context.stacked(value) do |current|
            if !array
              block.call(current)
              # Necessary call #itself to loose the dynamic reference
              field.write_value(current.itself)
            else
              field.resolve_with_array!(current, &block)
            end
          end
        end

        # Check if the given class is in the pool, or add a new instance to the
        # pool, and then set the instance as the current object
        def instance_for(klass)
          @objects_pool[klass] ||= begin
            @objects_pool.each_value.find do |value|
              value < klass
            end || begin
              instance = klass.new
              instance = DynamicInstance.new(instance) unless klass < GraphQL::Schema ||
                klass < GraphQL::Types::Object
              instance
            end
          end
        end

        # Trigger an event using a set of filtered objects from +request.stack+.
        # {+trigger_all+}[rdoc-ref:Rails::GraphQL::Event#trigger_all].
        # The filter is based on the listeners that were collected by the
        # strategy.
        def trigger_event(event_name, **xargs)
          return unless listening_to?(event_name)

          objects = listeners[event_name.to_sym] & request.stack
          return if objects.empty?

          Event.trigger(event_name, objects, self, **xargs)
        end

        # Check what kind of event listeners the object have, in order to speed
        # up processing by avoiding unnecesary event instances
        def add_listener(object)
          return unless add_listeners?

          object.all_listeners.each do |event_name|
            listeners[event_name] << object
          end
        end

        protected

          # Clean and enable the collecting of listeners
          def release_listeners!
            @listeners = @base_listeners.dup
          end

          # Disable the collecting of listeners
          def lock_listeners!
            listeners.freeze
          end

          # A shortcut for +release_listeners!+ and +lock_listeners!+
          def collect_listeners
            release_listeners!
            yield
            lock_listeners!
          end

          # This is where the strategy is most effective. By preparing the tree,
          # it can load data in a pretty smart way
          def collect_data
            @data_pool = {}
            if listening_to?(:prepare)
              yield
            end
          end

          # Initiate the response context, named
          # ({Request::Context}[rdoc-ref:Rails::GraphQL::Request::Context])
          # and start collecting results
          def collect_response(operation)
            @context = request.build(Request::Context, request, operation)
            @objects_pool = {}
            yield
          ensure
            @context = @objects_pool = @data_pool = @listeners = nil
          end

          # Fetch the data for a given field and set as the first element
          # of the returned list
          def data_for(result, field)
            return result << @data_pool[field] if @data_pool.key?(field)
            return if field.entry_point?

            current, key = @context.current, field.method_name
            return result << current.public_send(key) if current.respond_to?(key)
            result << current[key] if current.respond_to?(:[]) && current.key?(key)
          end

        private

          # Collect the base listeners from the request
          def collect_request_listeners
            @listeners = Hash.new { |h, k| h[k] = [] }
            add_listener(request)

            lock_listeners!
            @base_listeners = @listeners
          end
      end
    end
  end
end
