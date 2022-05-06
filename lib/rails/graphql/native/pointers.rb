# frozen_string_literal: true

module Rails
  module GraphQL
    module Native
      # This helps to make sure that any parser error is correctly initialized
      # and easy to ready. It also release the error using GC.
      class ParseError < FFI::MemoryPointer
        def initialize(*)
          super(:pointer)
        end

        def to_s
          empty? ? '' : read_pointer.read_string
        end

        def empty?
          read_pointer.null?
        end
      end
    end
  end
end
