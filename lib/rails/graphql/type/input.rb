# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InputType
      #
      # Input defines a set of input fields; the input fields are either
      # scalars, enums, or other input objects.
      # See http://spec.graphql.org/June2018/#InputObjectTypeDefinition
      class Input < Type
        extend Helpers::WithFields

        setup! kind: :input_object, input: true

        self.field_types = [Field::InputField].freeze
        self.valid_field_types = [Type::Enum, Type::Input, Type::Scalar].freeze

        class << self
          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            return false unless value.is_a?(Hash)

            value = build_defaults(fields).merge(value)
            return false unless value.size.eql?(fields.size)

            fields.values.all? { |item| item.valid_input?(value[item.gql_name]) }
          end

          # Turn the given value into an ruby representation of it
          def deserialize(value)
            fields.transform_values do |field|
              field.deserialize(value[field.gql_name])
            end
          end

          # Build a hash with the default values for each of the given fields
          def build_defaults
            values = fields.values.map(&:default)
            fields.values.map(&:gql_name).zip(values).to_h
          end

          def inspect # :nodoc:
            args = fields.each_value.map(&:inspect)
            args = args.presence && "(#{args.join(', ')})"
            "#<GraphQL::Input #{gql_name}#{args}>"
          end
        end
      end
    end
  end
end
