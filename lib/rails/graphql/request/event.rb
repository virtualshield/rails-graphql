# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Event
      #
      # A small extension of the original event to support extra methods and
      # helpers when performing events during a request
      class Event < GraphQL::Event
        OBJECT_BASED_READERS = %i[fragment spread].freeze

        delegate :errors, :context, :extensions, to: :request
        delegate :instance_for, to: :strategy
        delegate :memo, :schema, to: :source
        delegate :subscription_provider, to: :schema

        attr_reader :strategy, :request, :index

        # Enhance the trigger settings based on the default for a request event
        def self.trigger(event_name, object, *args, **xargs, &block)
          xargs[:phase] ||= :execution
          xargs[:fallback_trigger!] ||= :trigger_all unless block.present?
          super(event_name, object, *args, **xargs, &block)
        end

        def initialize(name, strategy, source = nil, **data)
          @request = strategy.request
          @strategy = strategy

          source ||= request.stack.first
          @index, source = source, request.stack[1] if source.is_a?(Numeric)

          super(name, source, **data)
        end

        # TODO: Implement a faster way to check if if the event is from the
        # same source by separating exclusive events beforehand

        # If the source is a field, than also compare to the actual field
        def same_source?(other)
          super || (source.try(:kind) == :field && source.field == other)
        end

        # Provide a way to access the current field value
        # TODO: Maybe change this to +current+ to get the value by reference
        def current_value
          resolver&.current_value
        end

        alias current current_value

        # Allow access to the prepared data of the underlying field
        def prepared_data
          strategy.prepared_data_for(source) if Component::Field === source
        end

        # Allow changing the prepared data of the underlying field
        def prepared_data=(value)
          strategy.store_data(source, value) if Component::Field === source
        end
        # event.strategy.store_data(event.source, result)

        # Provide a way to set the current value
        def current_value=(value)
          resolver&.override_value(value)
        end

        # Get the operation for the current source
        def operation
          (object.kind == :operation) ? object : source.operation
        end

        # Return the strategy context as the resolver
        def resolver
          strategy.context
        end

        # Return the actual field when the source is a request field
        def field
          source.field if source.try(:kind) == :field
        end

        # Check if the event source is of the given +type+
        def for?(type)
          source.of_type?(type)
        end

        # Check if the current +object+ is of the given +item+
        def on?(item)
          object.of_type?(item)
        end

        # Provide access to field arguments
        def argument(name)
          args_source.try(:[], name.to_sym)
        end

        alias arg argument

        # A combined helper for +instance_for+ and +set_on+
        def on_instance(object, &block)
          set_on(object.is_a?(Class) ? instance_for(object) : object, &block)
        end

        protected

          # When performing an event under a field object, the keyed-based
          # parameters of a proc callback will be associated with actual field
          # arguments
          def args_source
            data[:args_source] || (source.try(:kind) === :field && source.arguments)
          end

        private

          # Check for object based readers
          def respond_to_missing?(method_name, include_private = false)
            OBJECT_BASED_READERS.include?(method_name) ||
              current_value&.respond_to?(method_name, include_private) ||
              super
          end

          # If the +method_name+ matches the kind of the current +object+, then
          # it will return the object
          def method_missing(method_name, *args, **xargs, &block)
            if OBJECT_BASED_READERS.include?(method_name)
              object if object.kind == method_name
            elsif current_value&.respond_to?(method_name)
              current_value&.public_send(method_name, *args, **xargs, &block)
            else
              super
            end
          end
      end
    end
  end
end
