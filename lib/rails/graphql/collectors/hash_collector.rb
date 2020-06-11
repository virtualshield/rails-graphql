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
          @request.schema.encode_with_active_support? \
            ? ::ActiveSupport::JSON.encode(@data) \
            : ::JSON.generate(@data)
        end

        private

          def pointer
            @stack.last || @data
          end
      end
    end
  end
end
