# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:

        # Strcuture for an operation info
        FIELD_OBJECT = {
          name: nil,
          alias: nil,
          arguments: [],
          directives: [],
          selection: nil,
        }.freeze

        # Collect all the fields
        def collect_fields(*nodes, &block)
          return if nodes.empty?

          setup_for(:fields) do
            register(:end_visit_field) do |node|
              block.call(node, stack.pop)
            end

            nodes.each { |node| visit(node, self, user_data) }
          end
        end

        private

          def setup_for_fields # :nodoc:
            register(:visit_name) do |node|
              object[:alias] = object[:name] unless object[:name].nil?
              (object[:name] = node_name(node))                                 && true
            end

            register(:visit_field) do |node|
              (stack << FIELD_OBJECT.deep_dup)                                  && true
            end

            register(:visit_argument) do |node|
              (object[:arguments] << node)                                      && false
            end

            register(:visit_directive) do |node|
              (object[:directives] << node)                                     && false
            end

            register(:visit_selection_set) do |node|
              object.nil? ? true : (object[:selection] = node)                  && false
            end
          end
      end
    end
  end
end
