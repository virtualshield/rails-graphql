# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Query Operation
      #
      # Handles a query operation inside a request.
      class Operation::Query < Operation
        redefine_singleton_method(:query?) { true }
      end
    end
  end
end
