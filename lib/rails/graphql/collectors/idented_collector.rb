module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors # :nodoc:
      # This collector helps building a indented string
      class IdentedCollector
        def initialize(initial = 0, size = 2, auto_eol: true)
          @size = size
          @val = [[initial, '']]
          @auto_eol = auto_eol
        end

        def indented(start = nil, finish = nil, auto_eol = @auto_eol)
          self << start unless start.nil?

          indent
          yield

          @val.last.pop while @val.last.last.blank?
          unindent

          @val.pop(2) if blank?(-2)

          self << finish unless finish.nil?
          self.eol if auto_eol
          self
        end

        def value
          @val.map do |(ident, *content)|
            next if content.size.eql?(1) && content.first.blank?
            ident = (' ' * ident)
            ident + content.join("\n#{ident}")
          end.compact.join("\n")
        end

        def puts(str)
          @val.last.last << str
          eol
        end

        def <<(str)
          @val.last.last << str
          self
        end

        def eol
          @val.last << ''
          self
        end

        def indent
          return @val.last[0] += @size if blank?
          @val << [last_ident + @size, '']
          self
        end

        def unindent
          return @val.last[0] -= @size if blank?
          @val << [last_ident - @size, '']
          self
        end

        def last_ident
          @val.last.first
        end

        def blank?(pos = -1)
          @val[pos].size.eql?(2) && @val[pos].last.empty?
        end
      end
    end
  end
end
