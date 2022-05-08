# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Strategy
      #
      # This is the base class for the strategies of resolving a request.
      class Strategy
        extend ActiveSupport::Autoload

        autoload :DynamicInstance

        autoload :SequencedStrategy
        autoload :MultiQueryStrategy

        # Configurations for the prepare step
        PREPARE_XARGS = { object?: true, reverse?: true }.freeze

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
          @objects_pool = {}
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

        # When a +field+ has a perform step, run it under the context of the
        # prepared value from the data pool
        def perform(field, data = nil)
          context.stacked(data || @data_pool[field]) do
            safe_store_data(field) do
              Event.trigger(:perform, field, self, &field.performer)
            end
          end
        end

        # Execute the prepare step for the given +field+ and execute the given
        # block using context stack
        def prepare(field, &block)
          value = safe_store_data(field) do
            Event.trigger(:prepare, field, self, **PREPARE_XARGS)
          end

          perform(field, value) if field.mutation?

          value = @data_pool[field]
          context.stacked(value, &block) unless value.nil?
        end

        # Resolve a value for a given object, It uses the +args+ to prevent
        # problems with nil values.
        def resolve(field, *args, array: false, decorate: false, &block)
          resolve_data_for(field, args)

          value = args.last
          value = field.decorate(value) if decorate
          context.stacked(value) do |current|
            if !array
              block.call(current)
              field.write_value(current)
            else
              field.write_array(current, &block)
            end
          end
        end

        def resolve_data_for(field, args)
          return unless args.size.zero?

          rescue_with_handler(field: field) do
            if field.try(:dynamic_resolver?)
              prepared = @data_pool[field]
              args << Event.trigger(:resolve, field, self, prepared: prepared, &field.resolver)
            else
              data_for(args, field)
            end
          end
        end

        # Safe trigger an event and ensure to send any exception to the request
        # handler
        def rescue_with_handler(**extra)
          yield
        rescue => error
          request.rescue_with_handler(error, **extra)
        end

        # Check if the given class is in the pool, or add a new instance to the
        # pool, and then set the instance as the current object
        def instance_for(klass)
          @objects_pool[klass] ||= begin
            @objects_pool.each_value.find do |value|
              value.is_a?(klass)
            end || begin
              instance = klass.new
              instance = DynamicInstance.new(instance) unless klass < GraphQL::Schema ||
                klass < GraphQL::Type::Object
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

        # Store a given resolve +value+ for a given +field+
        def store_data(field, value)
          @data_pool[field] = value
        end

        # Only store a given +value+ for a given +field+ if it is not set yet
        def safe_store_data(field, value = nil)
          rescue_with_handler(field: field) do
            value ||= yield if block_given?
            @data_pool[field] ||= value unless value.nil?
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
          def collect_data(force = false)
            @data_pool = {}
            @context = request.build(Request::Context)

            # TODO: Create an orchestrator to allow cross query loading
            yield if force || listening_to?(:prepare)
          end

          # Initiate the response context, named
          # ({Request::Context}[rdoc-ref:Rails::GraphQL::Request::Context])
          # and start collecting results
          def collect_response
            yield
          ensure
            @context = @objects_pool = @data_pool = @listeners = nil
          end

          # Fetch the data for a given field and set as the first element
          # of the returned list
          def data_for(result, field)
            return result << @data_pool[field] if @data_pool.key?(field)
            return if field.entry_point?

            current, key = context.current_value, field.method_name
            return result << current.public_send(key) if current.respond_to?(key)

            result << current[key] if current.respond_to?(:key?) && current.key?(key)
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
