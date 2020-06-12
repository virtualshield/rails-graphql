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
          kind: 'fragment',
          directives: [],
          selection: nil,
        }.freeze

        # Collect all the definitions
        def collect_definitions(node, &block)
          setup_for(:definition) do
            register(:end_visit_operation_definition) { |node| block.call(node, stack.pop) }
            register(:end_visit_fragment_definition)  { |node| block.call(node, stack.pop) }
            Native.visit(node, self, user_data)
          end
        end

        private

          def setup_for_definition # :nodoc:
            register(:visit_operation_definition) do |node|
              stack << OPERATION_OBJECT.dup
              (object[:kind] = Native.operation_type(node))                     && true
            end

            register(:visit_fragment_definition) do
              (stack << FRAGMENT_OBJECT.dup)                                    && true
            end

            register(:visit_name) do |node|
              (object[:name] = Native.node_name(node))                          && true
            end

            register(:visit_named_type) do |node|
              (object[:type] = Native.node_name(Native.fragment_name(node)))    && false
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
