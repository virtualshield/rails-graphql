# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The introspection object for any kind of type
      class Object::TypeObject < Object
        # List and not null are not actually types, but they still need to
        # some how exist for introspection purposes
        FAKE_TYPES = {
          list: {
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
          return EMPTY_ARRAY unless current.object? || current.interface?

          list =
            if current.respond_to?(:enabled_fields)
              current.enabled_fields
            else
              current.fields.values.select(&:enabled?)
            end

          unless include_deprecated
            list = list.reject { |field| field.using?(deprecated_directive) }
          end

          list.reject(&:internal?).sort_by do |field|
            (field.name == :id) ? '' : field.gql_name
          end
        end

        def enum_values(include_deprecated:)
          return EMPTY_ARRAY unless current.enum?

          descriptions = all_value_description
          deprecated = all_deprecated_values

          list = all_values.lazy
          list = list.reject { |value| deprecated.key?(value) } \
            unless include_deprecated || deprecated.nil?

          list.map do |value|
            OpenStruct.new(
              name: value,
              description: descriptions[value],
              is_deprecated: (deprecated.nil? ? false : deprecated.key?(value)),
              deprecation_reason: deprecated.try(:[], value),
            )
          end
        end

        def interfaces
          (current.object? && current.all_interfaces) || EMPTY_ARRAY
        end

        def possible_types
          (current.interface? && current.all_types) ||
            (current.union? && current.all_members) || EMPTY_ARRAY
        end

        def input_fields
          (current.input? && current.enabled_fields) || EMPTY_ARRAY
        end
      end
    end
  end
end
