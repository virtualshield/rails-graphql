# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # DateTime uses a ISO 8601 string to excahnge the value.
      class Scalar::DateTimeScalar < Scalar
        set_ar_type! :datetime

        desc 'The DateTime scalar type represents a ISO 8601 string value.'

        class << self
          def valid_input?(value)
            super && (Time.iso8601(value) rescue false)
          end

          def valid_output?(value)
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
