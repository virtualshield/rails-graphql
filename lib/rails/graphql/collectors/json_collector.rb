# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors # :nodoc:
      # This collector helps building a JSON response using the string approach,
      # which has better performance, since all the encoding is performed up
      # front. The drawback is that it can't return an hash.
      class JsonCollector
        def initialize(request)
          @request = request

          @current_value = String.new
          @stack_value = []

          @current_array = false
          @stack_array = []

          @current_plain_array = false
          @stack_plain_array = []
        end

        # Shortcut for starting and ending a stack while execute a block.
        def with_stack(key, array: false, plain: false)
          return unless block_given?
          start_stack(array, plain)
          yield
          end_stack(key, array, plain)
        rescue
          pop_size = array && !plain ? 2 : 1
          @current_value = @stack_value.pop(pop_size).first
          @current_array = @stack_array.pop(pop_size).first
          raise
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
          (@current_value << ',') unless @current_value.blank?

          if @current_array
            @current_value << value
          else
            @current_value << '"'
            @current_value << key.to_s
            @current_value << '":'
            @current_value << value.to_s
          end
        end

        # Same as +add+ but this always encode the +value+ beforehand.
        def safe_add(key, value)
          add(key, value.nil? ? 'null' : value.to_json)
        end

        # Serialize is a helper to call the correct method on types before add
        def serialize(klass, key, value)
          add(key, klass.to_json(value))
        end

        # Mark the start of a new element on the array.
        def next
          return unless @stack_array.last === :complex
          (@stack_value.last << ',') unless @stack_value.last.blank?
          @stack_value.last << to_s
          @current_value = String.new
        end

        # Get the current result
        def to_s
          @current_array ? "[#{@current_value}]" : "{#{@current_value}}"
        end

        private

          # Start a new part of the collector. When set +as_array+, the result
          # of the stack will be encolsed by +[]+.
          def start_stack(as_array = false, plain_array = false)
            @stack_value << @current_value
            @stack_array << @current_array

            if as_array && !plain_array
              @stack_value << String.new
              @stack_array << :complex
              as_array = false
            end

            @current_value = String.new
            @current_array = as_array
          end

          # Finalize a stack and set the result on the given +key+.
          def end_stack(key, as_array = false, plain_array = false)
            if as_array && !plain_array
              @current_value = @stack_value.pop
              @current_array = @stack_array.pop
            end

            result = to_s
            @current_value = @stack_value.pop
            @current_array = @stack_array.pop
            add(key, result)
          end
      end
    end
  end
end
