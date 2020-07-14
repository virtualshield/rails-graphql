# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The introspection object for any kind of type
      class Object::TypeObject < Object::AssignedObject
        self.assigned_to = 'Rails::GraphQL::Type'
        self.spec_object = true

        rename! '__Type'

        desc <<~DESC
          The fundamental unit of any GraphQL Schema is the type. There are six
          kinds of named type definitions in GraphQL, and two wrapping types.

          The most basic type is a +Scalar+. A scalar represents a primitive value,
          like a string or an integer.

          +Scalars+ and +Enums+ form the leaves in response trees; the intermediate
          levels are +Object+ types, which define a set of fields.

          An +Interface+ defines a list of fields; +Object+ types that implement
          that interface are guaranteed to implement those fields.

          A +Union+ defines a list of possible types; similar to interfaces,
          whenever the type system claims a union will be returned, one of the
          possible types will be returned.

          Finally, oftentimes it is useful to provide complex structs as inputs
          to GraphQL field arguments or variables; the +Input Object+ type allows
          the schema to define exactly what data is expected.
        DESC

        field :kind,           '__TypeKind',   null: false,
          method_name: :kind_enum

        field :name,           :string,
          method_name: :gql_name

        field :description,    :string

        field :fields,         '__Field',      array: true, nullable: false do
          desc 'OBJECT and INTERFACE only'
          argument :include_deprecated, :boolean, default: false
        end

        field :interfaces,     '__Type',       array: true, nullable: false,
          method_name: :all_interfaces, desc: 'OBJECT only'

        field :possible_types, '__Type',       array: true, nullable: false,
          desc: 'INTERFACE and UNION only'

        field :enum_values,    '__EnumValue',  array: true, nullable: false do
          desc 'ENUM only'
          argument :include_deprecated, :boolean, default: false
        end

        field :input_fields,   '__InputValue', array: true, nullable: false,
          desc: 'INPUT_OBJECT only'

        field :of_type,        '__Type',
          desc: 'NON_NULL and LIST only'

        def fields
          return unless object? || interface?

          list = fields.each_value
          list = list.reject { |field| field.using?(:deprecated) } \
            unless args.include_deprecated

          list
        end

        def enum_values
          descs = all_value_description
          deprecated = all_deprecated_values

          list = all_values.lazy
          list = list.reject { |value| deprecated.key?(value) } \
            unless args.include_deprecated

          list.map do |value|
            OpenStruct.new(
              name: value,
              description: descs[value],
              is_deprecated: deprecated.key?(value),
              deprecation_reason: deprecated[value],
            )
          end
        end

        def possible_types
          return objects if interface?
          return all_members if union?
        end

        def input_fields
          fields.each_value if input?
        end

        def of_type
        end
      end
    end
  end
end
