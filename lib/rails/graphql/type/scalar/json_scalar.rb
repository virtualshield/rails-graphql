# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Handles an unstructured JSON data
      class Scalar::JsonScalar < Scalar
        rename! 'JSON'

        desc <<~DESC
          The JSON scalar type represents an unstructured JSON data
          with all its available keys and values.
        DESC

        use :specified_by, url: 'https://www.rfc-editor.org/rfc/rfc8259'

        class << self
          def valid_input?(value)
            valid_token?(value, :hash) || value.is_a?(::Hash)
          end

          def valid_output?(value)
            value.is_a?(::Hash)
          end

          def to_json(value)
            value.to_json
          end

          def as_json(value)
            value.as_json
          end

          def deserialize(value)
            value.is_a?(::GQLParser::Token) ? JSON.parse(value) : value
          end
        end
      end
    end
  end
end
