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
        field :type,          '__Type', null: false, method_name: :build_type
        field :default_value, :string

        FAKE_TYPES = {
          list: { kind: :list, name: 'List', object?: true, description: '...' },
          non_null: { kind: :non_null, name: 'NON Null', object?: true, description: '...'}
        }.freeze

        def build_type
          result = current.type_klass
          result = fake_type_object(:non_null, result) if current.nullable?
          result = fake_type_object(:list, result)     if current.array?
          result = fake_type_object(:non_null, result) if current.null?
          result
        end

        def fake_type_object(type, subtype)
          OpenStruct.new(**FAKE_TYPES[type].merge(of_type: subtype))
        end
      end
    end
  end
end
