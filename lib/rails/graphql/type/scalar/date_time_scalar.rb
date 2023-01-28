# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # DateTime uses a ISO 8601 string to exchange the value.
      class Scalar::DateTimeScalar < Scalar
        aliases :datetime

        desc 'The DateTime scalar type represents a ISO 8601 string value.'

        use :specified_by, url: 'https://www.rfc-editor.org/rfc/rfc3339'

        class << self
          def valid_input?(value)
            super && !!(Time.iso8601(value) rescue false)
          end

          def valid_output?(value)
            value.respond_to?(:to_time) && !!value.to_time
          end

          def as_json(value)
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
