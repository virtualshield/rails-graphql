# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The Boolean scalar type represents +true+ or +false+.
      #
      # See http://spec.graphql.org/June2018/#sec-Boolean
      class Scalar::BooleanScalar < Scalar
        self.spec_object = true
        aliases :bool

        desc 'The Boolean scalar type represents true or false.'

        FALSE_VALUES = ::ActiveModel::Type::Boolean::FALSE_VALUES

        class << self
          def valid_input?(value)
            valid_token?(value) || value === true || value === false
          end

          def valid_output?(*)
            true # Pretty much anything can be turned into a boolean
          end

          def as_json(value)
            !(value.nil? || FALSE_VALUES.include?(value))
          end

          def deserialize(value)
            as_json(value)
          end
        end
      end
    end
  end
end
