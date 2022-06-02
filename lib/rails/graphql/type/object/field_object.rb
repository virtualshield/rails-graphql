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

        def description
          current.description(schema.namespace)
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

        def args
          all_arguments&.values || EMPTY_ARRAY
        end

        def deprecated?
          !deprecated_instance.nil?
        end

        def deprecation_reason
          deprecated_instance&.args&.reason
        end

        private

          def deprecated_instance
            current.all_directives&.reverse_each do |item|
              return item if item.class <= deprecated_directive
            end

            nil
          end
      end
    end
  end
end
