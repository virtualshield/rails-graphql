# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:
        # Visit anything for given +nodes+
        def collect_debug(*nodes)
          return if nodes.empty?

          setup_for(:debug) do
            nodes.each do |node|
              @stack = 0
              visit(node, self, user_data)
              puts
            end
          end
        end

        private

          def setup_for_debug # :nodoc:
            MACROS.each do |key|
              register(:"visit_#{key}") do |node|
                puts (" " * @stack * 2) + "visit_#{key}"
                @stack += 2
                true
              end

              register(:"end_visit_#{key}") do |node|
                @stack -= 2
                puts (" " * @stack * 2) + "end_visit_#{key}"
              end
            end
          end
      end
    end
  end
end
