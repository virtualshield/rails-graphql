# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQl Multi Query Strategy
      #
      # This is a resolution strategy to solve requests that only contain
      # queries, allowing the strategy to collect all the information for all
      # the queries in a single step before resolving it.
      class Strategy::MultiQueryStrategy < Strategy
        self.priority = 10

        def self.can_resolve?(request) # :nodoc:
          false
          # request.operations.values.all?(&:query?)
        end

        def resolve!
          response.with_stack(:data) do
            operations.each_value(&:prepare!)
          end
        end

        def debug!
          @debug = true
        end
      end
    end
  end
end
