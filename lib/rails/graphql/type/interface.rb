# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InterfaceType
      #
      # Interfaces represent a list of named fields and their types.
      # See http://spec.graphql.org/June2018/#InterfaceTypeDefinition
      #
      # This class doesn't implements +valid_output?+ nor any of the output like
      # methods because the Object class that uses interface already fetches
      # all the fields for its composition and does the validating and
      # serializing process.
      class Interface < Type
        extend Helpers::WithFields

        setup! output: true

        self.field_types = [Field::OutputField].freeze
        self.valid_field_types = [
          Type::Enum,
          Type::Interface,
          Type::Object,
          Type::Scalar,
          Type::Union,
        ].freeze

        class << self
          # Check if the other type is equivalent, by checking if the other is
          # an object and the object implements this interface
          def ==(other)
            super || (other.object? && other.implements?(self))
          end

          def inspect # :nodoc:
            parts = fields.each_value.map(&:inspect)
            parts = parts.presence && "{#{parts.join(', ')}}"
            "#<GraphQL::Interface #{gql_name} #{parts}>"
          end

          # Check if the given object is properly implementing this interface
          def validate!(object = nil)
            super if defined? super
            return if object.nil?

            missing_keys = fields.keys - object.fields.keys
            raise ArgumentError, <<~MSG.squish if missing_keys.present?
              The "#{object.gql_name}" doesn't correctly implements "#{gql_name}", because
              the #{missing_keys.map { |key| fields[key].gql_name.inspect }.to_sentence}
              #{'field'.pluralize(missing_keys.size)} are missing.
            MSG

            fields.each do |key, item|
              raise ArgumentError, <<~MSG.squish unless object.fields[key] == item
                The "#{object.gql_name}" doesn't correctly implements "#{gql_name}",
                because the "#{item.gql_name}" field has different definition.
              MSG
            end

            nil # No exception already means valid
          end
        end
      end
    end
  end
end
