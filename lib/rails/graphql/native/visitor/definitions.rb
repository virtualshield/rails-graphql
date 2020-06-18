# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:

        # Strcuture for an operation info
        OPERATION_OBJECT = {
          name: nil,
          kind: nil,
          variables: [],
          directives: [],
          selection: nil,
        }.freeze

        # Strcuture for a fragment info
        FRAGMENT_OBJECT = {
          name: nil,
          type: nil,
          directives: [],
          selection: nil,
        }.freeze

        # Collect all the definitions
        def collect_definitions(*nodes, &block)
          return if nodes.empty?

          setup_for(:definition) do
            register(:end_visit_operation_definition) do |node|
              block.call(:operation, node, stack.pop)
            end

            register(:end_visit_fragment_definition)  do |node|
              block.call(:fragment, node, stack.pop)
            end

            nodes.each { |node| visit(node, self, user_data) }
          end
        end

        private

          def setup_for_definition # :nodoc:
            setup_with_name
            setup_with_type

            register(:visit_operation_definition) do |node|
              stack << OPERATION_OBJECT.dup
              (object[:kind] = operation_type(node))                            && true
            end

            register(:visit_fragment_definition) do
              (stack << FRAGMENT_OBJECT.dup)                                    && true
            end

            register(:visit_variable_definition) do |node|
              (object[:variables] << node)                                      && false
            end

            register(:visit_directive) do |node|
              (object[:directives] << node)                                     && false
            end

            register(:visit_selection_set) do |node|
              (object[:selection] = node)                                       && false
            end
          end

      end
    end
  end
end
