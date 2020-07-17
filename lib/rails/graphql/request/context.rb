# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Context
      #
      # This class is used as context for the response while processing fields,
      # objects, or any data that it's going to be placed on the response
      class Context
        CurrentValue = Class.new(ActiveSupport::ProxyObject) do
          delegate_missing_to '@stack.first'

          def initialize(stack)
            @stack = stack
          end
        end

        delegate :strategy, :stack, to: :request
        delegate :memo, to: :operation

        attr_reader :request, :operation, :current

        def initialize(request, operation)
          @stack = []
          @request = request
          @operation = operation
          @current = CurrentValue.new(@stack)
        end

        # Add, exec, and then remove the value from the stack
        def stacked(value)
          @stack.unshift(value) unless value.eql?(@stack[0])
          yield(@current)
        ensure
          @stack.shift
        end

        # Wait for a hit, which is when a possible new value was triggered,
        # and choose which value to return, or return +:all+
        def grab(idx = nil)
          @hits = []
          yield

          if idx.nil?
            @stack.unshift(@hits[0])
            return @current
          end

          return @hits if idx === :all
          @hits[idx]
        ensure
          @hits = nil
        end

        # Catch a new possible value and add to the list of hits
        def hit(value)
          @hits << value unless @hits.nil?
        end

        # Find the parent object
        def parent
          @stack.second
        end

        # Get all ancestors objects
        def ancestors
          @stack[1..-1]
        end

        # Change the current value, either form hits or the actual value
        def override_value(other)
          @hits.present? ? @hits[0] = other : @stack[0] = other
        end
      end
    end
  end
end
