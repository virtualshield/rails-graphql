module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors
      class ToGQL
        def initialize(indent_size = 2)
          @indent_size = indent_size
          @val = [[0, '']]
        end

        def indented(start = nil, finish = nil)
          self << start unless start.nil?

          eol.indent
          yield
          eol.unindent

          self << finish unless finish.nil?
          self
        end

        def value
          @val.map { |(ident, str)| (' ' * ident) + str }.join("\n")
        end

        def <<(str)
          @val.last[1] << str
          self
        end

        def eol
          @val << [last_ident, '']
          self
        end

        def indent
          @val.last[0] += @indent_size
          self
        end

        def unindent
          @val.last[0] -= @indent_size
          self
        end

        def last_ident
          @val.last.first
        end
      end
    end
  end
end
