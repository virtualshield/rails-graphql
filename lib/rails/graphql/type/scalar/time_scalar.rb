# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Uses as a float extension in order to transmit times (hours, minutes,
      # and seconds) as a numeric representation of seconds and miliseconds.
      class Scalar::TimeScalar < Scalar::FloatScalar
        define_singleton_method(:ar_type) { :time }

        self.spec_scalar = true
        self.description = <<~DESC.squish
          The Time scalar type represents a number of seconds and miliseconds.
        DESC

        EPOCH = Time.utc(2000, 1, 1)

        class << self
          def valid?(value)
            value.respond_to?(:to_time)
          end

          def to_hash(value)
            super(value.to_time - EPOCH)
          end

          def deserialize(value)
            EPOCH + super
          end
        end
      end
    end
  end
end
