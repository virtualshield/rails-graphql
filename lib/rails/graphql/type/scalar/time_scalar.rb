# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Uses as a float extension in order to transmit times (hours, minutes,
      # and seconds) as a numeric representation of seconds and miliseconds.
      class Scalar::TimeScalar < Scalar::FloatScalar
        redefine_singleton_method(:ar_type) { :time }

        desc <<~MSG
          The Time scalar type represents a number of seconds and miliseconds.
          A distance in time since regardless of the day and the timezone.
        MSG

        EPOCH = Time.utc(2000, 1, 1)

        class << self
          def valid_output?(value)
            value.respond_to?(:to_time)
          end

          def to_hash(value)
            super(value.to_time.change(year: 2000, day: 1, month: 1, offset: 0) - EPOCH)
          end

          def deserialize(value)
            EPOCH + super
          end
        end
      end
    end
  end
end
