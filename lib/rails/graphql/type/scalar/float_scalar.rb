# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The Float scalar type represents signed double-precision fractional
      # values as specified by
      # {IEEE 754}[http://en.wikipedia.org/wiki/IEEE_floating_point].
      #
      # See http://spec.graphql.org/June2018/#sec-Float
      class Scalar::FloatScalar < Scalar
        self.spec_object = true

        desc 'The Float scalar type represents signed double‐precision fractional values.'

        class << self
          def valid_input?(value)
            value.is_a?(Float)
          end

          def valid_output?(value)
            value.respond_to?(:to_f)
          end

          def as_json(value)
            value.to_f
          end
        end
      end
    end
  end
end
