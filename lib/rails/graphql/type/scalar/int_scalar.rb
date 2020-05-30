# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The Int scalar type represents a signed 32‐bit numeric
      # non‐fractional value.
      #
      # See http://spec.graphql.org/June2018/#sec-Int
      class Scalar::IntScalar < Scalar
        define_singleton_method(:ar_type) { :integer }

        self.spec_scalar = true
        self.description = <<~DESC
          The Int scalar type represents a signed 32‐bit numeric non‐fractional value.
        DESC

        max_value = (1 << 31)
        RANGE = (-max_value)...(max_value)

        class << self
          def valid?(value)
            value.respond_to?(:to_i) && RANGE.cover?(value.to_i)
          end

          def to_hash(value)
            value = value.to_i
            return value if RANGE.cover?(value)
            # TODO: Replace this exception to a specific type
            raise 'Invalid integer value'
          end
        end
      end
    end
  end
end
