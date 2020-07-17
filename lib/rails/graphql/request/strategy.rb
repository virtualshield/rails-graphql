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

        # Executes the strategy in the debug mode
        def debug!
          @debug_mode = true
        end

        # Checks if it's in debug mode
        def debug_mode?
          defined?(@debug_mode)
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

        # Fetch the data for a given field
        def data_for(field, data = nil, &block)
          return @context.stacked(data, &block) unless data.nil?

          return block.call(@context.grab { data_from_resolver(field) }) \
            if field.dynamic_resolver?

          return block.call if @context.blank?

          nested_value = @context.current.try(field.name) \
            || @context.current.try(:[], field.name)

          @context.stacked(nested_value, &block)
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

        # Trigger the resolver callback defined on the field
        def data_from_resolver(field)
          xargs = { object?: true, request: @request, context: @context }
          Event.trigger(field, :resolver, request.stack.first, :execution, **xargs)
        ensure
          change_current_object(nil)
        end

        # Trigger an event using a set of filtered objects from +request.stack+.
        # {+trigger_all+}[rdoc-ref:Rails::GraphQL::Event#trigger_all].
        # The filter is based on the listeners that were collected by the
        # strategy.
        def trigger_event(event_name, **xargs)
          return unless listening_to?(event_name)

          objects = listeners[event_name.to_sym] & request.stack
          return if objects.empty?

          source = request.stack.first

          xargs[:all?] = true
          xargs[:request] = @request
          xargs[:context] = @context if @context.present?

          Event.trigger(objects.to_a, event_name, source, :execution, **xargs) { @context }
        ensure
          change_current_object(nil)
        end

        # Check what kind of event listeners the object have, in order to speed
        # up processing by avoiding unnecesary event instances
        def add_listener(object)
          return unless add_listeners?
          list = []

          if object.is_a?(Component::Field)
            list += object.field.listeners
          elsif object.respond_to?(:all_directives)
            object.all_directives.each { |d| list += d.listeners }
          end

          list.flatten.each do |event_name|
            listeners[event_name.to_sym] << object
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
            return false unless listening_to?(:prepare)
            # TODO: Correctly implement data collector
          end

          # Initiate the response context, named
          # ({Request::Context}[rdoc-ref:Rails::GraphQL::Request::Context])
          # and start collecting results
          def collect_response(operation)
            @context = Request::Context.new(request, operation)
            @objects_pool = {}
            yield
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
