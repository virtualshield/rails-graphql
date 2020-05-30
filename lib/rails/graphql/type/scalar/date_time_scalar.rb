# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # DateTime uses a ISO 8601 string to excahnge the value.
      class Scalar::DateTimeScalar < Scalar
        define_singleton_method(:ar_type) { :datetime }

        self.spec_scalar = true
        self.description = <<~DESC.squish
          The DateTime scalar type represents a ISO 8601 string value.
        DESC

        class << self
          def valid?(value)
            value.respond_to?(:to_time)
          end

          def to_hash(value)
            value.to_time.iso8601
          end

          def deserialize(value)
            Time.iso8601(value)
          end
        end
      end
    end
  end
end
