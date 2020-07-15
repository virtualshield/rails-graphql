# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      class Component # :nodoc:
        # = GraphQL Request Component Query Operation
        #
        # Handles a query operation inside a request.
        class Operation::Query < Operation
          redefine_singleton_method(:query?) { true }
        end
      end
    end
  end
end
