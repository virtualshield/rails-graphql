# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      # This class helps to store the result of the parser, the pointer to the
      # ast node. It will also be correctly garbage-collected.
      class AstNode < FFI::AutoPointer
        def self.release(ptr)
          Native.free_node(ptr)
        end
      end

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
