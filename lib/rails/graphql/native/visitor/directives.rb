# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:

        # Strcuture for an operation info
        DIRECTIVE_OBJECT = {
          name: nil,
          arguments: {},
        }.freeze

        # Collect all the directives
        def collect_directives(*nodes, &block)
          return if nodes.empty?

          setup_for(:directives) do
            register(:end_visit_directive) do |node|
              block.call(stack.pop)
            end

            nodes.each { |node| visit(node, self, user_data) }
          end
        end

        private

          def setup_for_directives # :nodoc:
            setup_with_name
            setup_with_arguments

            register(:visit_variable) do |node|
              (stack << variable_name(node))                                    && false
            end

            register(:visit_directive) do |node|
              (stack << DIRECTIVE_OBJECT.deep_dup)                              && true
            end
          end
      end
    end
  end
end
