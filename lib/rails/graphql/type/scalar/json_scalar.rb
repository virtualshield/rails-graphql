# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Handles an unstructured JSON data
      class Scalar::JsonScalar < Scalar
        desc 'Provides an unstructured JSON data with all its available kyes and values.'

        class << self
          def valid_input?(value)
            value.is_a?(Hash)
          end

          def valid_output?(value)
            value.is_a?(Hash)
          end

          def to_json(value)
            value.to_json
          end

          def as_json(value)
            value.as_json
          end
        end
      end
    end
  end
end
