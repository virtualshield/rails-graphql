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

        attr_reader :listeners, :request

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
        end

        # Check if it's enabled to collect listeners
        def add_listeners?
          listeners.frozen?
        end

        # Check if any listener were actually added
        def listeners?
          @has_listeners.present?
        end

        # Clean and enable the collecting of listeners
        def release_listeners!
          @listeners = {}
          @has_listeners = false
          add_listener(schema)
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

        # Executes the strategy in the normal mode
        def resolve!
          raise NotImplementedError
        end

        # Executes the strategy in the debug mode
        def debug!
          raise NotImplementedError
        end

        # When running an stacked operation, make sure that the object was added
        # to the list of the listeners
        def stacked(object, &block)
          add_listener(object) if add_listeners?
          request.stacked(object, &block)
        end

        # Trigger an event using a set of filtered objects from +request.stack+.
        # {+trigger_all+}[rdoc-ref:Rails::GraphQL::Event#trigger_all].
        # The filter is based on the listeners that were collected by the
        # strategy.
        def trigger_event(event_name, **xargs, &block)
          return unless listeners?

          objects = request.stack.select do |object|
            listeners[object]&.include?(event_name)
          end

          return if objects.empty?

          xargs[:all] = true
          xargs[:request] = self
          Event.trigger(objects, event_name, request.stack.first, :execution, **xargs, &block)
        end

        # Check what kind of event listeners the object have, in order to speed
        # up processing by avoiding unnecesary event instances
        def add_listener(object)
          return if listeners.key?(object)
          list = Set.new

          if object.respond_to?(:directives)
            object.directives.each { |d| list += d.listeners }
          end

          if object.is_a?(Component::Field)
            list += object.field.listeners
          end

          @has_listeners = true if list.any?
          listeners[object] = list
        end
      end
    end
  end
end
