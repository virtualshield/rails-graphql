# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQl Multi Query Strategy
      #
      # This is a resolution strategy to solve requests that only contain
      # queries, allowing the strategy to collect all the information for all
      # the queries in a single step before resolving it.
      class Strategy::MultiQueryStrategy < Strategy
        self.priority = 10

        def self.can_resolve?(request)
          request.operations.values.all?(&:query?)
        end

        # Executes the strategy in the normal mode
        def resolve!
          response.with_stack(:data) do
            for_each_operation { |op| collect_listeners { op.organize! } }
            for_each_operation { |op| collect_data      { op.prepare!  } }
            for_each_operation { |op| collect_response  { op.resolve!  } }
          end
        end

        private

          # Execute a given block for each defined operation
          def for_each_operation
            operations.each_value { |op| yield op }
          end
      end
    end
  end
end
