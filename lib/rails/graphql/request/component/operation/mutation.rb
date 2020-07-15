# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      class Component # :nodoc:
        # = GraphQL Request Component Mutation Operation
        #
        # Handles a mutation operation inside a request.
        class Operation::Mutation < Operation
          redefine_singleton_method(:mutation?) { true }
        end
      end
    end
  end
end
