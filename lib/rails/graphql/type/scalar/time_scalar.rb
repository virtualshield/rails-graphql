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
          The Time scalar type that represents a distance in time using hours,
          minutes, seconds, and miliseconds.
        MSG

        # A +base_object+ helps to identify what methods are actually available
        # to work as resolvers
        class_attribute :precision, instance_writer: false, default: 6

        class << self
          def valid_input?(value)
            super && value.match?(/\d+:\d\d(:\d\d(\.\d+)?)?/)
          end

          def valid_output?(value)
            value.respond_to?(:to_time)
          end

          def to_hash(value)
            value.to_time.strftime('%%T.%%%dN' % precision)
          end

          def deserialize(value)
            '2000-01-01 ' + value.to_time
          end
        end
      end
    end
  end
end
