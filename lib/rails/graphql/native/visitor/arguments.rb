# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:

        # Strcuture for an argument info
        ARGUMENT_OBJECT = {
          name: nil,
          value: nil,
          variable: nil,
        }.freeze

        # Collect all the arguments
        def collect_arguments(*nodes, &block)
          return if nodes.empty?

          setup_for(:arguments) do
            register(:end_visit_argument) do |node|
              stack[-2][:value] = stack.pop if stack.size > 1
              block.call(stack.pop)
            end

            nodes.each { |node| visit(node, self, user_data) }
          end
        end

        private

          def setup_for_arguments # :nodoc:
            setup_with_name
            setup_with_value

            register(:visit_argument) do |node|
              (stack << ARGUMENT_OBJECT.deep_dup)                               && true
            end

            register(:visit_variable) do |node|
              (object[:variable] = node_name(variable_name(node)))              && false
            end
          end
      end
    end
  end
end
