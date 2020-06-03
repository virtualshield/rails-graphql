# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The Boolean scalar type represents +true+ or +false+.
      #
      # See http://spec.graphql.org/June2018/#sec-Boolean
      class Scalar::BooleanScalar < Scalar
        self.spec_object = true
        set_ar_type! :boolean
        aliases :bool

        desc 'The Boolean scalar type represents true or false.'

        FALSE_VALUES = ::ActiveModel::Type::Boolean::FALSE_VALUES

        class << self
          def valid_input?(value)
            value === true || value === false
          end

          def valid_output?(value)
            value.respond_to?(:present?)
          end

          def to_hash(value)
            value.present?
          end

          def deserialize(value)
            !FALSE_VALUES.include?(value)
          end
        end
      end
    end
  end
end
