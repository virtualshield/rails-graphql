# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Context
      #
      # This class is used as context for the response while processing fields,
      # objects, or any data that it's going to be placed on the response
      class Context
        delegate :strategy, :stack, to: :request
        delegate :memo, to: :operation

        attr_reader :request, :operation, :current

        def initialize(request, operation)
          @stack = []
          @request = request
          @operation = operation
          @current = Helpers::AttributeDelegator.new(self, :current_value, cache: false)
        end

        # Add, exec, and then remove the value from the stack
        def stacked(value)
          @stack.unshift(value) unless value.eql?(@stack[0])
          yield(@current)
        ensure
          @stack.shift
        end

        # Find the parent object
        def parent
          @stack.second
        end

        # Get all ancestors objects
        def ancestors
          @stack[1..-1]
        end

        # Get the current value, which basically means basically the first item
        # on the current stafck
        def current_value
          @stack[0]
        end

        # Change the current value, either form hits or the actual value
        def override_value(other)
          @stack[0] = other
        end

        alias current_value= override_value
      end
    end
  end
end
