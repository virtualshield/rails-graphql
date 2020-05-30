# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Date uses a ISO 8601 string to excahnge the value.
      class Scalar::DateScalar < Scalar
        define_singleton_method(:ar_type) { :date }

        self.spec_scalar = true
        self.description = <<~DESC.squish
          The Date scalar type represents a ISO 8601 string value.
        DESC

        class << self
          def valid?(value)
            value.respond_to?(:to_date)
          end

          def to_hash(value)
            value.to_date.iso8601
          end

          def deserialize(value)
            Date.iso8601(value)
          end
        end
      end
    end
  end
end
