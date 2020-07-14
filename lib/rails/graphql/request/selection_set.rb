# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper module to collect the fields from fragments, operations, and also
      # other fields.
      module SelectionSet
        DATA_PARTS = %i[selection]

        attr_reader :fields

        # Add the +selection+ to the list of data parts
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        protected

          def parse_selection!
            @fields = {}

            visitor.collect_fields(*data[:selection]) do |node, data|
              fields[data[:name]] = Field.new(self, node, data)
            end unless data[:selection].nil? || data[:selection].null?

            assing_fields!
            @fields.freeze
          end

          def debug_fields!
            response.indented("* Fields(#{fields.size})") do
              fields.each_value.with_index do |field, i|
                response.eol if i > 0
                field.debug_prepare!
              end
            end if fields.any?
          end

          # Using +fields_source+, find the needed ones to be assigned to the
          # current requested fields. As shown by benchmark, since the index is
          # based on Symbols, the best way to find +gql_name+ based fields is
          # through interation and search. Complexity O(n)
          def assing_fields!
            pending = fields.size
            return if pending.zero?

            fields_source.each_value do |source_field|
              next unless (field = fields[source_field.gql_name])

              field.assing_field(source_field)
              break if (pending -= 1) === 0
            end
          end
      end
    end
  end
end
