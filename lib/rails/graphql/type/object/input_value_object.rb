# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The introspection object for a input object
      class Object::InputValueObject < Object
        self.assigned_to = 'Rails::GraphQL::Field::InputField'
        self.spec_object = true

        def self.valid_member?(value)
          value.is_a?(GraphQL::Argument) || super
        end

        delegate :fake_type_object, to: 'Object::TypeObject'

        rename! '__InputValue'

        desc <<~DESC
          Alongside with scalars and enums, input value objects allow the user
          to provide values to arguments on fields and directives. Different
          from those, input values accepts a list of keyed values, instead of
          a single value.
        DESC

        field :name,          :string,  null: false, method_name: :gql_name
        field :description,   :string
        field :type,          '__Type', null: false, method_name: :build_type
        field :default_value, :string

        def default_value
          current.to_json if current.default_value?
        end

        def build_type
          result = current.type_klass

          if current.array?
            result = fake_type_object(:non_null, result) unless current.nullable?
            result = fake_type_object(:list,     result)
          end

          result = fake_type_object(:non_null, result) unless current.null?
          result
        end
      end
    end
  end
end
