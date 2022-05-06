# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      class Component
        # = GraphQL Request Component Subscription Operation
        #
        # Handles a subscription operation inside a request.
        class Operation::Subscription < Operation
          redefine_singleton_method(:subscription?) { true }
        end
      end
    end
  end
end
