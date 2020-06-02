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

        self.valid_field_types = [Type::Enum, Type::Input, Type::Scalar].freeze
        self.field_types = [Field::InputField].freeze

        class << self
          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            return false unless value.is_a?(Hash)

            value = build_defaults(fields).merge(value.transform_keys(&:underscore))
            return false unless value.size.eql?(fields.size)

            # It's okay to symbolize user input here because we already checked
            # that the keys are the same as the ones defined on fields
            value.all? { |key, val| fields[key.to_sym].valid_input?(val) }
          end

          # Build a hash with the default values for each of the given fields
          def build_defaults
            values = fields.values.map(&:default)
            fields.keys.zip(values).to_h.stringify_keys
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
