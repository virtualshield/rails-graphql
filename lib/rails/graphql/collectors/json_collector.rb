module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors # :nodoc:
      # This collector helps building a JSON response using the string approach,
      # which has better performance, since all the encoding is performed up
      # front. The drawback is that it can't return an hash.
      class JsonCollector
        def initialize(request)
          @request = request

          @current_array = false
          @stack_array = []

          @current_value = ''
          @stack_value = []
        end

        # Shortcut for starting and ending a stack while execute a block.
        def with_stack(key, array: false)
          return unless block_given?
          start_stack(array)
          yield
          end_stack(key)
        end

        # Start a new part of the collector. When set +as_array+, the result of
        # the stack will be encolsed by +[]+.
        def start_stack(as_array = false)
          @stack_array << @current_array
          @stack_value << @current_value

          @current_array = as_array
          @current_value = ''
        end

        # Finalize a stack and set the result on the given +key+.
        def end_stack(key)
          result = to_s
          @current_array = @stack_array.pop
          @current_value = @stack_value.pop
          @current_value << %("#{key}":#{result},)
        end

        # Mark the start of a new element on the array.
        def next
          if @current_array
            @current_value.chomp!(',')
            @current_value << '},{'
          else
            @current_array = true
          end
        end

        # Append to the responsa data all the errors that happened during the
        # request process.
        def append_errors(errors)
          return if errors.empty?
          add('errors', errors.to_json)
        end

        # Add the given +value+ to the given +key+. Ensure to encode the value
        # before calling this function.
        def add(key, value)
          @current_value << %("#{key}":#{value},)
        end

        # Same as +add+ but this always encode the +value+ beforehand.
        def safe_add(key, value)
          add(key, value.to_json)
        end

        # Get the final result.
        def to_s
          result = @current_value.delete_suffix(',')
          @current_array ? "[{#{result}}]" : "{#{result}}"
        end
      end
    end
  end
end
