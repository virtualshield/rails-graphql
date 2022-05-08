# frozen_string_literal: true

module Rails
  module GraphQL
    # Module related to some methods regarding the introspection of a schema
    module Introspection
      # When register is called, add introspection related elements
      def register!(*)
        super if defined? super
        enable_introspection! if !introspection? && config.enable_introspection

        # Although this is not necessary besides for introspection, there is no
        # real disadvantage on adding it
        Helpers::WithSchemaFields::SCHEMA_FIELD_TYPES.each do |type, name|
          GraphQL.type_map.register_alias(name, namespace: namespace) do
            result = public_send(:"#{type}_type")
            type.eql?(:query) || result.present? ? result : nil
          end
        end
      end

      # Check if the schema has introspection enabled
      def introspection?
        false
      end

      protected

        # Enaqble introspection fields
        def enable_introspection!
          redefine_singleton_method(:introspection?) { true }
          introspection_dependencies!

          safe_add_field(:query, :__schema, '__Schema', null: false) do
            resolve { schema }
          end

          safe_add_field(:query, :__type, '__Type') do
            argument(:name, :string, null: false)
            resolve { schema.find_type(argument(:name)) }
          end
        end

        # Add the introspection dependencies, but only when necessary
        def introspection_dependencies!
          GraphQL.type_map.add_dependencies([
            "#{__dir__}/type/enum/directive_location_enum",
            "#{__dir__}/type/enum/type_kind_enum",

            "#{__dir__}/type/object/directive_object",
            "#{__dir__}/type/object/enum_value_object",
            "#{__dir__}/type/object/field_object",
            "#{__dir__}/type/object/input_value_object",
            "#{__dir__}/type/object/schema_object",
            "#{__dir__}/type/object/type_object",
          ], to: :base)
        end
    end
  end
end
