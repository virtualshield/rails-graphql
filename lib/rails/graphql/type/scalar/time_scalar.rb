# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Uses as a float extension in order to transmit times (hours, minutes,
      # and seconds) as a numeric representation of seconds and milliseconds.
      class Scalar::TimeScalar < Scalar::FloatScalar
        EPOCH = Time.utc(2000, 1, 1)

        set_ar_type! :time

        desc <<~MSG
          The Time scalar type represents a number of seconds and milliseconds.
          A distance in time since regardless of the day and the timezone.
        MSG

        class << self
          def valid_output?(value)
            value.respond_to?(:to_time)
          end

          def to_hash(value)
            super(value.to_time.change(year: 2000, day: 1, month: 1, offset: 0) - EPOCH)
          end

          def deserialize(value)
            EPOCH + to_hash(value)
          end
        end
      end
    end
  end
end
