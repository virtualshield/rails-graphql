# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper module to collect the fields from fragments, operations, and also
      # other fields.
      module SelectionSet
        attr_reader :selection

        protected

          # Helper parser for selection fields that also asssign the actual
          # field defined under the schema structure
          def parse_selection(nodes)
            return if nodes.nil?

            @selection = {}
            assigners = Hash.new { |h, k| h[k] = [] }

            nodes.each do |node|
              component = add_component(node)
              assigners[component.name.to_s] << component if component.assignable?
            end

            assing_fields!(assigners)
            @selection.freeze
          end

          # Using +fields_source+, find the needed ones to be assigned to the
          # current requested fields. As shown by benchmark, since the index is
          # based on Symbols, the best way to find +gql_name+ based fields is
          # through interation and search. Complexity O(n)
          def assing_fields!(assigners)
            pending = assigners.map(&:size).reduce(:+) || 0
            return if pending.zero?

            fields_source.each_value do |field|
              next unless assigners.key?(field.gql_name)

              items = assigners[field.gql_name]
              items.each_with_object(field).each(&:assing_to)
              break if (pending -= items.size) === 0
            end
          end

          # Recursive operation that perform the organization step for the
          # selection
          def organize_fields
            selection.each_value(&:organize!) if selection.present?
          end

          # Find all the fields that have a prepare step and execute them
          def prepare_fields
            selection.each_value(&:prepare!) if selection.present?
          end

          # Trigger the process of resolving the value of all the fields. Since
          # complex object may or may not be inside an array, this helps to
          # decide if a new stack should be started or not
          def resolve_fields(object = nil)
            return unless selection.present?

            items = selection.each_value
            items = items.each_with_object(object) unless object.nil?
            iterator = object.nil? ? :resolve! : :resolve_with!

            return items.each(&iterator) unless stacked_selection?
            response.with_stack(gql_name) { items.each(&iterator) }
          end

        private

          def add_component(node)
            item_name = node[1] || node[0]

            if node.of_type?(:spread)
              selection[selection.size] = request.build(Component::Spread, self, node)
            elsif node[0] === '__typename'
              selection[item_name] ||= request.build(Component::Typename, self, node)
            else
              selection[item_name] ||= request.build(Component::Field, self, node)
            end
          end
      end
    end
  end
end
