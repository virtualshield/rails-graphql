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
            operations.each_value do |operation|
              operation.prepare!
            end
          end
        end

        def debug!
          @debug = true

          response.indented('# Prepare phase') do
            operations.each_value.with_index do |operation, i|
              response.eol if i > 0
              operation.debug_prepare!
            end
          end
        end
      end
    end
  end
end
