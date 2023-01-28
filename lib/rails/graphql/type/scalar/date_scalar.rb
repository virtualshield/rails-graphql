# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Date uses a ISO 8601 string to exchange the value.
      class Scalar::DateScalar < Scalar
        desc 'The Date scalar type represents a ISO 8601 string value.'

        use :specified_by, url: 'https://www.rfc-editor.org/rfc/rfc3339'

        class << self
          def valid_input?(value)
            super && !!Date.iso8601(value)
          rescue Date::Error
            false
          end

          def valid_output?(value)
            value.respond_to?(:to_date) && !!value.to_date
          rescue Date::Error
            false
          end

          def as_json(value)
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
