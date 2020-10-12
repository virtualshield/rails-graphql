# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The introspection object for a field on objects and interfaces
      class Object::FieldObject < Object::AssignedObject
        self.assigned_to = 'Rails::GraphQL::Field'
        self.spec_object = true

        rename! '__Field'

        desc <<~DESC
          Fields are the elements that compose both Objects and Interfaces. Each
          field in these other objects may contain arguments and always yields
          a value of a specific type.
        DESC

        field :name,               :string,        null: false
        field :description,        :string
        field :args,               '__InputValue', full: true
        field :type,               '__Type',       null: false,
              method_name: :build_type
        field :is_deprecated,      :boolean,       null: false
        field :deprecation_reason, :string

        FAKE_TYPES = {
          list: { kind: :list, name: 'List', object?: true,  description: '...' },
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
