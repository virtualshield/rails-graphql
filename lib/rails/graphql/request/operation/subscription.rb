# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Subscription Operation
      #
      # Handles a subscription operation inside a request.
      class Operation::Subscription < Operation
        redefine_singleton_method(:subscription?) { true }
      end
    end
  end
end
