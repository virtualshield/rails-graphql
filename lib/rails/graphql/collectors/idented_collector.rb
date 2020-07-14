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
          unindent

          @val.pop(2) if @val[-2].size.eql?(2) && @val[-2].last.empty?

          self << finish unless finish.nil?
          self.eol if auto_eol
          self
        end

        def value
          @val.map do |(ident, *content)|
            next if content.size.eql?(1) && content.first.blank?
            content.pop if content.last.empty?

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

        alias print <<

        def eol
          @val.last << ''
          self
        end

        def indent
          @val << [last_ident + @size, '']
          self
        end

        def unindent
          @val << [last_ident - @size, '']
          self
        end

        def last_ident
          @val.last.first
        end
      end
    end
  end
end
