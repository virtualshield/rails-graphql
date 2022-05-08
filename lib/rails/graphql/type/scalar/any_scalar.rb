# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Handles any type of data for both input and output
      class Scalar::AnyScalar < Scalar
        desc 'The Any scalar type allows anything for both input and output.'

        class << self
          def valid_input?(value)
            true
          end

          def valid_output?(value)
            true
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
