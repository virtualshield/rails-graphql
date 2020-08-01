# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Event
      #
      # A small extension of the original event to support extra methods and
      # helpers when performing events during a request
      class Event < GraphQL::Event
        OBJECT_BASED_READERS = %i[field fragment operation spread]

        delegate :schema, :errors, to: :request
        delegate :context, to: :strategy
        delegate :memo, to: :object

        attr_reader :strategy, :request, :index

        # Enhance the trigger settings based on the default for a request event
        def self.trigger(event_name, object, *args, **xargs, &block)
          xargs[:phase] ||= :execution
          xargs[:all?] ||= true unless block.present?
          super(event_name, object, *args, **xargs, &block)
        end

        def initialize(name, strategy, **data)
          @request = strategy.request
          @strategy = strategy

          source = request.stack.first
          @index, source = source, request.stack.second if source.is_a?(Numeric)

          super(name, source, **data)
        end

        # Check if the event source is of the given +type+
        def for?(type)
          source.of_type?(type)
        end

        # Check if the current +object+ is of the given +type+
        def on?(item)
          object.of_type?(type)
        end

        protected

          # When performing an event under a field object, the keyed-based
          # parameters of a proc callback will be associated with actual field
          # arguments
          def args_source
            object.arguments if object.kind === :field
          end

        private
          delegate :instance_for, to: :strategy

          # Find a type or a constant based on the given +object+
          def class_of(object)
            return object unless item.is_a?(Symbol) || item.is_a?(String)
            schema.find_type(item) || ::GraphQL.const_get(item)
          end

          # Check for object based readers
          def respond_to_missing?(method_name, *)
            OBJECT_BASED_READERS.include?(method_name) || super
          end

          # If the +method_name+ matches the kind of the current +object+, then
          # it will return the object
          def method_missing(method_name, *)
            return super unless OBJECT_BASED_READERS.include?(method_name)
            return object if object.kind === method_name
          end
      end
    end
  end
end
