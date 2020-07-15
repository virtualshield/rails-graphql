# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper module to collect the fields from fragments, operations, and also
      # other fields.
      module SelectionSet
        DATA_PARTS = %i[selection]

        attr_reader :selection

        # Add the +selection+ to the list of data parts
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        protected

          # Helper parser for selection fields that also asssign the actual
          # field defined under the schema structure
          def parse_selection
            @selection = {}

            visitor.collect_fields(*data[:selection]) do |kind, node, data|
              if kind === :spread
                selection[selection.size] = Component::Spread.new(self, node, data)
              else
                selection[data[:name]] = Component::Field.new(self, node, data)
              end
            end unless data[:selection].nil? || data[:selection].null?

            # assing_fields!
            @selection.freeze
          end

          # Recursive operation that perform the organization step for the
          # selection
          def organize_fields
            selection.each_value(&:organize!)
          end

          # Recursive operation that perform the organization step for the
          # selection while in debug mode
          def debug_organize_fields
            logger.indented("* Fields(#{selection.size})") do
              selection.each_value.with_index do |field, i|
                logger.eol if i > 0
                field.debug_organize!
              end
            end if selection.any?
          end

          # Using +fields_source+, find the needed ones to be assigned to the
          # current requested fields. As shown by benchmark, since the index is
          # based on Symbols, the best way to find +gql_name+ based fields is
          # through interation and search. Complexity O(n)
          def assing_fields!
            pending = selection.size
            return if pending.zero?

            fields_source.each_value do |field|
              next unless (item = selection[field.gql_name])

              item.assing_to(field)
              break if (pending -= 1) === 0
            end
          end
      end
    end
  end
end
