# frozen_string_literal: true

module Rails
  module GraphQL
    module Collectors
      # = GraphQL JSON Collector
      #
      # This collector helps building a JSON response using the string approach,
      # which has better performance, since all the encoding is performed up
      # front. The drawback is that it can't return a hash.
      class JsonCollector
        def initialize(request)
          @request = request

          @current_keys = Set.new
          @stack_keys = []

          @current_value = StringIO.new
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
          @current_keys = @stack_keys.pop
          raise
        end

        # Append to the response data all the errors that happened during the
        # request process.
        def append_errors(errors)
          return if errors.empty?
          add('errors', errors.to_json)
        end

        # Append to the response anything added to the extensions
        def append_extensions(extensions)
          return if extensions.empty?
          add('extensions', extensions.to_json)
        end

        # Add the given +value+ to the given +key+. Ensure to encode the value
        # before calling this function.
        def add(key, value)
          (@current_value << ',') if @current_value.pos > 0
          @current_keys << key

          if @current_array
            @current_value << value
          else
            @current_value << '"' << +key.to_s << '"' << ':' << +value.to_s
          end
        end

        # Check if the given +key+ has been added already
        def key?(key)
          @current_keys.include?(key)
        end

        # Same as +add+ but this always encode the +value+ beforehand.
        def safe_add(key, value)
          add(key, value.nil? ? 'null' : value.to_json)
        end

        # Serialize is a helper to call the correct method on types before add
        def serialize(klass, key, value)
          result = klass.to_json(value)
          add(key, result)
          result&.object_id
        end

        # Duplicate the given value given the object id of its cache
        def dup_from_cache(key, oid)
          add(key, ObjectSpace._id2ref(oid))
        rescue RangeError
          raise CacheUnavailableError, +"The cache ref #{oid} is no longer available"
        end

        # Mark the start of a new element on the array.
        def next
          return unless @stack_array.last === :complex
          (@stack_value.last << ',') if @stack_value.last.pos > 0
          @stack_value.last << to_s

          @current_value = StringIO.new
          @current_keys = Set.new
        end

        # Get the current result
        def to_s
          if @current_array
            +'[' << @current_value.string << ']'
          else
            +'{' << @current_value.string << '}'
          end
        end

        alias to_json to_s

        private

          # Start a new part of the collector. When set +as_array+, the result
          # of the stack will be enclosed by +[]+.
          def start_stack(as_array = false, plain_array = false)
            @stack_value << @current_value
            @stack_array << @current_array
            @stack_keys << @current_keys

            if as_array && !plain_array
              @stack_value << StringIO.new
              @stack_array << :complex
              as_array = false
            end

            @current_value = StringIO.new
            @current_array = as_array
            @current_keys = Set.new
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
            @current_keys = @stack_keys.pop
            add(key, result)
            result.object_id
          end
      end
    end
  end
end
