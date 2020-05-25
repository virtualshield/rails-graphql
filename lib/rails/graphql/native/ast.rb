module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      ##
      # Simplify access to FFI::Struct#members by defining the instance methods
      # after calling +setup+
      class Accessor < FFI::Struct
        # private :[]
        # private :[]=

        # ##
        # # After the original FFI::Struct initialization, generate the accessors
        # def self.layout(*)
        #   super

        #   generated = members.map do |sym_name|
        #     m_name = sym_name.to_s.delete_prefix('get').delete_prefix('_').underscore

        #     <<-CODE
        #       def #{m_name}; self[:#{sym_name}]; end
        #       def #{m_name}=(val); self[:#{sym_name}] = val; end
        #     CODE
        #   end

        #   class_eval(generated.join("\n"))
        # end
      end

      class GraphQLAstLocation < Accessor # :nodoc:
        layout(beginLine: :uint, beginColumn: :uint, endLine: :uint, endColumn: :uint)
      end

      class GraphQLAstNode < Accessor # :nodoc:
        layout(getLocation: callback([], GraphQLAstLocation))
      end

      class GraphQLAstDocument < Accessor # :nodoc:
        layout(
          location: :pointer,
          definitions: :pointer,
        )
      end
    end
  end
end

# x = Rails::GraphQL::Native.parse('{ heeloWorld }')
# y = Rails::GraphQL::Native::GraphQLAstDocument.new(x)
# z = Rails::GraphQL::Native::GraphQLAstLocation.new(y[:location])
