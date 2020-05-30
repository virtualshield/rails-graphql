# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The Float scalar type represents signed double‐precision fractional
      # values as specified by
      # {IEEE 754}[http://en.wikipedia.org/wiki/IEEE_floating_point].
      #
      # See http://spec.graphql.org/June2018/#sec-Float
      class Scalar::FloatScalar < Scalar
        define_singleton_method(:ar_type) { :float }

        self.spec_scalar = true
        self.description = <<~DESC
          The Float scalar type represents signed double‐precision fractional values.
        DESC

        class << self
          def valid?(value)
            value.respond_to?(:to_f)
          end

          def to_hash(value)
            value.to_f
          end
        end
      end
    end
  end
end
