# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The introspection object for a input object
      class Object::InputValueObject < Object::AssignedObject
        self.assigned_to = 'Rails::GraphQL::Field::InputField'
        self.spec_object = true

        rename! '__InputValue'

        desc <<~DESC
          Alongside with scalars and enums, input value objects allow the user
          to provide values to arguments on fields and directives. Different
          from those, input values accepts a list of keyed values, instead of
          a single value.
        DESC

        field :name,          :string,  null: false
        field :description,   :string
        field :type,          '__Type', null: false
        field :default_value, :string
      end
    end
  end
end
