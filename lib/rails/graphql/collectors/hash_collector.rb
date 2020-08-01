module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors # :nodoc:
      # This collector helps building a JSON response using the hash approach,
      # where the value is kept as an hash and later turn into a string
      class HashCollector
        def initialize(request)
          @request = request
          @stack = []
          @data = {}
        end

        # Checks if the collector prefer writing values as string
        def prefer_string?
          false
        end

        # Shortcut for starting and ending a stack while execute a block.
        def with_stack(key, array: false, plain: false)
          return unless block_given?
          start_stack(array, plain)
          yield
          end_stack(key, array, plain)
        rescue
          @data = @stack.pop
          raise
        end

        # Add the given +value+ to the given +key+.
        def add(key, value)
          @data.is_a?(Array) ? @data << value : object[key.to_s] = value
        end

        alias safe_add add

        # Mark the start of a new element on the array.
        def next
          return unless @stack.last.is_a?(Array)
          @stack.last << @data
          @data = {}
        end

        # Append to the responsa data all the errors that happened during the
        # request process
        def append_errors(errors)
          return if errors.empty?
          @data[:errors] = errors.to_a
        end

        def to_h
          @data
        end

        def to_s
          ::JSON.generate(@data)
          # # TODO: Fix when settings start working correctly
          # Core.encode_with_active_support? \
          #   ? ::ActiveSupport::JSON.encode(@data) \
          #   : ::JSON.generate(@data)
        end

        private

          # Start a new part of the collector. When set +as_array+, the result
          # of the stack will be an array.
          def start_stack(as_array = false, plain_array = false)
            @stack << @data
            @stack << [] if as_array && !plain_array
            @data = as_array && plain_array ? [] : {}
          end

          # Finalize a stack and set the result on the given +key+.
          def end_stack(key, as_array = false, plain_array = false)
            result = as_array && !plain_array ? @stack.pop : @data

            @data = @stack.pop
            add(key, result)
          end
      end
    end
  end
end
