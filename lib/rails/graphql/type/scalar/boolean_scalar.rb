# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The Boolean scalar type represents +true+ or +false+.
      #
      # See http://spec.graphql.org/June2018/#sec-Boolean
      class Scalar::BooleanScalar < Scalar
        define_singleton_method(:ar_type) { :boolean }

        self.spec_scalar = true
        self.description = <<~DESC
          The Boolean scalar type represents true or false.
        DESC

        FALSE_VALUES = ActiveModel::Type::Boolean::FALSE_VALUES

        class << self
          def valid?(value)
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
