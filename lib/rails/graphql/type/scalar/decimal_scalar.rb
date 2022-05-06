# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Similar to float, but implies extra precision, making sure that all the
      # decimal-point numbers are kept. As Bigint, it uses a string so it won't
      # go against the spec.
      class Scalar::DecimalScalar < Scalar
        desc <<~DESC
          The Decimal scalar type represents signed fractional values with extra precision.
          The values are exchange as string.
        DESC

        class << self
          def valid_input?(value)
            super && value.match?(/\A[+-]?\d+\.\d+\z/)
          end

          def valid_output?(value)
            value.respond_to?(:to_d)
          end

          def as_json(value)
            value.to_d.to_s
          end

          def deserialize(value)
            value.to_d
          end
        end
      end
    end
  end
end
