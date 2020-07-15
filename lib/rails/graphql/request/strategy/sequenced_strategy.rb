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

        # Executes the strategy in the normal mode
        def resolve!
          response.with_stack(:data) do
            operations.each_value do |op|
              collect_listeners { op.organize! }

              # op.prepare!
              # op.fetch!
              # op.resolve!
            end
          end
        end

        # Executes the strategy in the debug mode
        def debug!
          response.with_stack(:data) do
            operations.each_value.with_index do |op, i|
              logger.eol if i > 0
              logger.indented('# Organize phase') do
                collect_listeners { op.debug_organize! }
              end

              # logger.indented('# Prepare phase')  { op.debug_prepare! }
              # logger.indented('# Fetch phase')    { op.debug_fetch! }
              # logger.indented('# Resolve phase')  { op.debug_resolve! }
            end
          end
        end
      end
    end
  end
end
