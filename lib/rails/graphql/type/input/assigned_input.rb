# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL Assigned InputType
      #
      # Similar to the {AssignedObject}[rdoc-ref:Rails::GraphQL::Type::Object::AssignedObject]
      # but that works with input objects
      class Input::AssignedInput < Input
        extend Helpers::WithAssignment

        self.abstract = true
      end
    end
  end
end
