# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQl Strategy Dynamic Instance
      #
      # When an event is call on non-object types, this class allows both
      # finding a method on two different places, the interface or union
      # definition, or on the correct object type-class.
      class Strategy::DynamicInstance < Helpers::AttributeDelegator
        def instance_variable_set(ivar, value)
          __getobj__.instance_variable_set(ivar, value)
          __current_object__&.instance_variable_set(ivar, value)
        end

        private

          def respond_to_missing?(method_name, include_private = false)
            __current_object__&.respond_to?(method_name, include_private) || super
          end

          def method_missing(method_name, *args, **xargs, &block)
            object = __current_object__

            return super unless object&.respond_to?(method_name)
            object.public_send(method_name, *args, **xargs, &block)
          end

          def __current_object__
            return unless __getobj__.instance_variable_defined?(:@event)

            event = __getobj__.instance_variable_get(:@event)
            return if event.nil? || (object = event.source.try(:current_object)).nil?

            event.strategy.instance_for(object)
          end
      end
    end
  end
end
