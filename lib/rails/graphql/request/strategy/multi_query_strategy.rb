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
          request.operations.each_value.all? { |op| op.of_type?(:query) }
        end

        # Executes the strategy in the normal mode
        def resolve!
          response.with_stack('data') do
            for_each_operation { |op| collect_listeners { op.organize! } }
            for_each_operation { |op| collect_data      { op.prepare!  } }
            for_each_operation { |op| collect_response  { op.resolve!  } }
          end
        end
      end
    end
  end
end
