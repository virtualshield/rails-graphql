# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:

        # Strcuture for an variable info
        VARIABLE_OBJECT = {
          name: nil,
          type: nil,
          null: true,
          array: false,
          nullable: true,
          default: nil,
        }.freeze

        # Collect all the variables
        def collect_variables(*nodes, &block)
          return if nodes.empty?

          setup_for(:variables) do
            register(:end_visit_variable_definition) do |node|
              stack[-2][:default] = stack.pop unless default_value(node).null?
              block.call(stack.pop)
            end

            nodes.each { |node| visit(node, self, user_data) }
          end
        end

        private

          def setup_for_variables # :nodoc:
            setup_with_name
            setup_with_type
            setup_with_value

            register(:visit_variable_definition) do |node|
              (stack << VARIABLE_OBJECT.dup)                                    && true
            end

            register(:visit_list_type) do |node|
              (object[:array] = true)                                           && true
            end

            register(:visit_non_null_type) do |node|
              key = object[:array] ? :nullable : :null
              object[key] = false
              true
            end
          end
      end
    end
  end
end



