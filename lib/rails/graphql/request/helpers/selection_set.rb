# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper module to collect the fields from fragments, operations, and also
      # other fields.
      module SelectionSet
        attr_reader :selection

        protected

          # Helper parser for selection fields that also asssign the actual
          # field defined under the schema structure
          def parse_selection
            @selection = {}
            assigners = {}

            visitor.collect_fields(*data[:selection]) do |kind, node, data|
              component = add_component(kind, node, data)
              assigners[component.name] = component if component.assignable?
            end unless data[:selection].nil? || data[:selection].null?

            assing_fields!(assigners)
            @selection.freeze
          end

          # Using +fields_source+, find the needed ones to be assigned to the
          # current requested fields. As shown by benchmark, since the index is
          # based on Symbols, the best way to find +gql_name+ based fields is
          # through interation and search. Complexity O(n)
          def assing_fields!(assigners)
            pending = assigners.size
            return if pending.zero?

            fields_source.each_value do |field|
              next unless (item = assigners[field.gql_name])

              item.assing_to(field)
              break if (pending -= 1) === 0
            end
          end

          # Recursive operation that perform the organization step for the
          # selection
          def organize_fields
            selection.each_value(&:organize!) if selection.any?
          end

          # Trigger the process of resolving the value of all the fields. Since
          # complex object may or may not be inside an array, this helps to
          # decide if a new stack should be started or not
          def resolve_fields(object = nil)
            return unless selection.any?

            items = selection.each_value
            items = items.each_with_object(object) unless object.nil?
            iterator = object.nil? ? :resolve! : :resolve_with!

            return items.each(&iterator) unless stacked_selection?
            response.with_stack(gql_name) { items.each(&iterator) }
          end

        private

          def add_component(kind, node, data)
            item_name = data.try(:alias).presence || data[:name]

            if kind === :spread
              selection[selection.size] = request.build(Component::Spread, self, node, data)
            elsif data[:name] === '__typename'
              selection[item_name] ||= request.build(Component::Typename, self, node, data)
            else
              selection[item_name] ||= request.build(Component::Field, self, node, data)
            end
          end
      end
    end
  end
end
