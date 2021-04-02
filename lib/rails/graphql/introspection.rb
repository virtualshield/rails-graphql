# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Module related to some methods regarding the introspection of a schema
    module Introspection
      module ClassMethods # :nodoc: all
        def inherited(subclass)
          super if defined? super

          subclass.query_fields do
            field(:__schema, '__Schema', null: false) do
              resolve { schema }
            end

            field(:__type, '__Type') do
              argument(:name, :string, null: false)
              resolve { schema.find_type(argument(:name)) }
            end
          end
        end
      end

      def self.extended(other) # :nodoc:
        other.extend(Introspection::ClassMethods)
      end

      # When register is called, add introspection fields?
      def register!(*)
        super if defined? super
        return unless introspection?

        Helpers::WithSchemaFields::SCHEMA_FIELD_TYPES.each do |type, name|
          GraphQL.type_map.register_alias(name, namespace: namespace) do
            result = public_send("#{type}_type")
            type.eql?(:query) || result.present? ? result : nil
          end
        end
      end

      # Check if the schema has introspection enabled
      def introspection?
        true
      end

      # Remove introspection fields and disable introspection
      def disable_introspection!
        disable_fields(:query, :__schema, :__type)
        redefine_singleton_method(:introspection?) { false }
      end
    end
  end
end
