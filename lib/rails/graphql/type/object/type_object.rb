# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The introspection object for any kind of type
      class Object::TypeObject < Object::AssignedObject
        FAKE_TYPES = {
          list:     {
            kind: :list,
            kind_enum: 'LIST',
            name: 'List',
            object?: true,
            description: nil,
          },
          non_null: {
            kind: :non_null,
            kind_enum: 'NON_NULL',
            name: 'Non-Null',
            object?: true,
            description: nil,
          },
        }.freeze

        self.assigned_to = 'Rails::GraphQL::Type'
        self.spec_object = true

        def self.valid_member?(value)
          value.is_a?(OpenStruct) ? value.try(:object?) : super
        end

        def self.fake_type_object(type, subtype)
          OpenStruct.new(**FAKE_TYPES[type].merge(of_type: subtype))
        end

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
          desc: 'OBJECT only'

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

        def fields(include_deprecated:)
          return [] unless current.object? || current.interface?

          list = current.fields.values
          list = list.reject { |field| field.using?(deprecated_directive) } \
            unless include_deprecated

          list
        end

        def enum_values(include_deprecated:)
          return [] unless current.enum?

          descs = all_value_description
          deprecated = all_deprecated_values

          list = all_values.lazy
          list = list.reject { |value| deprecated.key?(value) } \
            unless include_deprecated

          # TODO: fix lazy enum
          list.map do |value|
            OpenStruct.new(
              name: value,
              description: descs[value],
              is_deprecated: deprecated.key?(value),
              deprecation_reason: deprecated[value],
            )
          end.force
        end

        def interfaces
          return [] unless current.object?
          current.all_interfaces || []
        end

        def possible_types
          return all_types if current.interface?
          current.union? ? all_members : []
        end

        def input_fields
          current.input? ? current.fields.values : []
        end
      end
    end
  end
end
