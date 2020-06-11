module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors # :nodoc:
      # This collector helps building a indented string
      class IdentedCollector
        def initialize(initial = 0, size = 2)
          @size = size
          @val = [[initial, '']]
        end

        def indented(start = nil, finish = nil)
          self << start unless start.nil?

          eol.indent
          yield
          unindent

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
          @val.last[0] += @size
          self
        end

        def unindent
          @val.last[0] -= @size
          self
        end

        def last_ident
          @val.last.first
        end
      end
    end
  end
end
