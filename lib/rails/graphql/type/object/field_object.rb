# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The introspection object for a field on objects and interfaces
      class Object::FieldObject < Object
        self.assigned_to = 'Rails::GraphQL::Field'
        self.spec_object = true

        delegate :fake_type_object, to: 'Object::TypeObject'

        rename! '__Field'

        desc <<~DESC
          Fields are the elements that compose both Objects and Interfaces. Each
          field in these other objects may contain arguments and always yields
          a value of a specific type.
        DESC

        field :name,               :string,        null: false, method_name: :gql_name
        field :description,        :string
        field :args,               '__InputValue', full: true
        field :type,               '__Type',       null: false, method_name: :build_type
        field :is_deprecated,      :boolean,       null: false, method_name: :deprecated?
        field :deprecation_reason, :string

        def build_type
          result = current.type_klass

          if current.array?
            result = fake_type_object(:non_null, result) unless current.nullable?
            result = fake_type_object(:list,     result)
          end

          result = fake_type_object(:non_null, result) unless current.null?
          result
        end

        def args
          all_arguments.values
        end

        def deprecated?
          current.using?(deprecated_directive)
        end

        def deprecation_reason
          current.all_directives.find { |item| item.is_a?(deprecated_directive) }&.args&.reason
        end
      end
    end
  end
end
