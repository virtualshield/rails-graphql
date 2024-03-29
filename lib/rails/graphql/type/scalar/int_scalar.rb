# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The Int scalar type represents a signed 32-bit numeric
      # non-fractional value.
      #
      # See http://spec.graphql.org/June2018/#sec-Int
      class Scalar::IntScalar < Scalar
        self.spec_object = true
        aliases :integer

        desc 'The Int scalar type represents a signed 32-bit numeric non-fractional value.'

        max_value = (1 << 31)
        RANGE = (-max_value...max_value).freeze

        class << self
          def valid_input?(value)
            (valid_token?(value) && RANGE.cover?(value.to_i)) ||
              (value.is_a?(Integer) && RANGE.cover?(value))
          end

          def valid_output?(value)
            value.respond_to?(:to_i) && RANGE.cover?(value.to_i)
          end

          def as_json(value)
            value = value.to_i
            value if RANGE.cover?(value)
          end
        end
      end
    end
  end
end
