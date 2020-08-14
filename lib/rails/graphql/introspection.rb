# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Module related to some methods regarding the introspection of a schema
    module Introspection
      # Check if the schema has introspection enabled
      def introspection?
        true
      end

      # Remove introspection fields and disable introspection
      def disable_introspection!
        redefine_singleton_method(:introspection?) { false }
      end

      # Before doing anything, register the introspection fields if needed and
      # then assign the schema field types
      def validate!(*)
        query_fields do
          field(:__schema, '__Schema', null: false) do
            resolve { |schema| schema }
          end

          field(:__type, '__Type') do
            argument(:name, :string, null: false)
            resolve { |schema, name:| schema.find_type!(name) }
          end
        end if introspection?

        Helpers::WithSchemaFields::SCHEMA_FIELD_TYPES.each do |type, name|
          Core.type_map.register_alias(name, namespace: namespace) do
            result = public_send("#{type}_type")
            type.eql?(:query) || result.fields.present? ? result : nil
          end
        end

        super if defined? super
      end
    end
  end
end
