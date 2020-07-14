# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQl Sequenced Strategy
      #
      # This is the default resolution strategy, where each operation is
      # performed in sequece, and they don't relate to each other in any way.
      class Strategy::SequencedStrategy < Strategy
        def self.can_resolve?(_) # :nodoc:
          true
        end

        def resolve!
          response.with_stack(:data) do
            operations.each_value do |op|
              op.organize!
              # op.prepare!
              # op.fetch!
              # op.resolve!
            end
          end
        end

        def debug!
          operations.each_value.with_index do |op, i|
            response.eol if i > 0
            response.indented('# Organize phase') { op.debug_organize! }
            # response.indented('# Prepare phase')  { op.debug_prepare! }
            # response.indented('# Fetch phase')    { op.debug_fetch! }
            # response.indented('# Resolve phase')  { op.debug_resolve! }
          end
        end
      end
    end
  end
end
