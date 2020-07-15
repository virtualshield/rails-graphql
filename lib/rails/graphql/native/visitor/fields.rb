# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct # :nodoc:

        # Strcuture for an field info
        FIELD_OBJECT = {
          name: nil,
          alias: nil,
          arguments: [],
          directives: [],
          selection: nil,
        }.freeze

        # Strcuture for an spread info
        SPREAD_OBJECT = {
          name: nil,
          type: nil,
          inline: false,
          directives: [],
          selection: nil,
        }

        # Collect all the fields
        def collect_fields(*nodes, &block)
          return if nodes.empty?

          setup_for(:fields) do
            register(:end_visit_field) do |node|
              block.call(:field, node, stack.pop)
            end

            register(:end_visit_fragment_spread) do |node|
              block.call(:spread, node, stack.pop)
            end

            register(:end_visit_inline_fragment) do |node|
              block.call(:spread, node, stack.pop.merge(inline: true))
            end

            nodes.each { |node| visit(node, self, user_data) }
          end
        end

        private

          def setup_for_fields # :nodoc:
            setup_with_type

            register(:visit_name) do |node|
              object[:alias] = object[:name] unless object[:name].nil?
              (object[:name] = node_name(node))                                 && true
            end

            register(:visit_field) do |node|
              (stack << FIELD_OBJECT.deep_dup)                                  && true
            end

            register(:visit_fragment_spread) do |node|
              (stack << SPREAD_OBJECT.deep_dup)                                 && true
            end

            register(:visit_inline_fragment) do |node|
              (stack << SPREAD_OBJECT.deep_dup)                                 && true
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
