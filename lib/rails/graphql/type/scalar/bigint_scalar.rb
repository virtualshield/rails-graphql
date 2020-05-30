# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Bigint basically removes the limit of the value, but it serializes as
      # a string so it won't go aginst the spec
      class Scalar::BigintScalar < Scalar
        define_singleton_method(:ar_type) { :string }

        self.description = <<~DESC.squish
          The Bigint scalar type represents a signed numeric non‐fractional value.
          It can go beyond the Int 32‐bit limit, but it's exchanged as a string.
        DESC

        class << self
          def valid?(value)
            value.respond_to?(:to_i)
          end

          def to_hash(value)
            value.to_i.to_s
          end

          def deserialize(value)
            value.to_i
          end
        end
      end
    end
  end
end
