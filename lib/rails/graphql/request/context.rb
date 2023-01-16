# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Context
      #
      # This class is used as context for the response while processing fields,
      # objects, or any data that it's going to be placed on the response
      class Context
        attr_reader :current

        def initialize
          @stack = []
          @current = Helpers::AttributeDelegator.new(self, :current_value, cache: false)
        end

        # Add, exec, and then remove the value from the stack
        def stacked(value)
          @stack.unshift(value) unless value.eql?(@stack[0])
          yield(@current)
        ensure
          @stack.shift
        end

        # Return a duplicated version of the stack, for safety
        def stack
          @stack.dup
        end

        # Get a value at the given +index+
        def at(index)
          @stack[index]
        end

        # Get all ancestors objects
        def ancestors
          @stack[1..-1]
        end

        # Find the parent object
        def parent
          at(1)
        end

        # Get the current value, which basically means basically the first item
        # on the current stack
        def current_value
          at(0)
        end

        # Change the current value, either form hits or the actual value
        def override_value(value)
          @stack[0] = value
        end

        alias current_value= override_value
      end
    end
  end
end
