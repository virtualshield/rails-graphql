# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Strategy
      #
      # This is the base class for the strategies of resolving a request.
      class Strategy
        extend ActiveSupport::Autoload

        autoload :SequencedStrategy
        autoload :MultiQueryStrategy

        # The priority of the strategy
        class_attribute :priority, instance_accessor: false, default: 1

        delegate :operations, :errors, :response, :schema, :logger, to: :request

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
          @current_object = nil
          collect_request_listeners
        end

        # Executes the strategy in the normal mode
        def resolve!
          raise NotImplementedError
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
        def resolve(field, *args, array: false, &block)
          data_for(args, field) unless args.one?
          args << Event.trigger(field, :resolver, self).first \
            if field.dynamic_resolver?

          # No need to move forward with the context if there's no way to fetch
          # a real value for the field
          return block.call(nil) unless args.one?

          # Now we have a value to set on the context
          @context.stacked(args.last) do |current|
            if !array
              block.call(current)
              field.write_value(current)
            elsif !current.respond_to?(:each)
              current.nil? ? block.call(current) : field.resolve_invalid
            else
              field.resolve_with_array!(current, &block)
            end
          end
        end

        # Check if the given class is in the pool, or add a new instance to the
        # pool, and then set the instance as the current object
        def instance_for(klass)
          begin
            @objects_pool[klass] ||= @objects_pool.each_value.find do |value|
              value < klass
            end || klass.new
          end.tap do |instance|
            change_current_object(instance, request.stack.first, @context.current)
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

          Event.trigger(objects, event_name, self, **xargs)
        ensure
          change_current_object(nil)
        end

        # Check what kind of event listeners the object have, in order to speed
        # up processing by avoiding unnecesary event instances
        def add_listener(object)
          return unless add_listeners?
          list = []

          if object.is_a?(Component::Field)
            list << object.field.listeners
          elsif object.respond_to?(:all_directives)
            object.all_directives.each { |d| list << d.listeners }
          end

          list.compact.reduce(:concat).each do |event_name|
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

          # A shortcut for +release_data!+ and +lock_data!+
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
          end

          # Fetch the data for a given field and set as the first element
          # of the returned list
          def data_for(result, field)
            return result << @data_pool[field] if @data_pool.key?(field)
            return if field.entry_point?

            current, key = @context.current, field.name
            return result << current.public_send(key) if current.respond_to?(key)
            result << current[key] if current.respond_to?(:[]) && current.key?(key)
          end

        private

          # Collect the base listeners from the request
          def collect_request_listeners
            @listeners = Hash.new { |h, k| h[k] = Set.new }
            add_listener(request.schema)

            lock_listeners!
            @base_listeners = @listeners
          end

          # Change the current active object instance
          def change_current_object(klass, field = nil, object = nil)
            @current_object = klass
            @current_object&.instance_variable_set(:@field, field)
            @current_object&.instance_variable_set(:@object, object)
          end
      end
    end
  end
end
