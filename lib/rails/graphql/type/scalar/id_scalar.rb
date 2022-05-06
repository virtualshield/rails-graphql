# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The ID scalar type represents a unique identifier, often used to
      # refetch an object or as the key for a cache. The ID type is serialized
      # in the same way as a +StringScalar+.
      #
      # See http://spec.graphql.org/June2018/#sec-ID
      class Scalar::IdScalar < Scalar
        self.spec_object = true

        rename! 'ID'

        desc <<~DESC
          The ID scalar type represents a unique identifier and it is serialized in the same
          way as a String but it accepts both numeric and string based values as input.
        DESC

        class << self
          def valid_input?(value)
            super || value.is_a?(Integer)
          end

          def as_json(value)
            value = value.to_s unless value.is_a?(String)
            value = value.encode(Encoding::UTF_8) unless value.encoding.eql?(Encoding::UTF_8)
            value
          end

          def deserialize(value)
            value.to_s
          end
        end
      end
    end
  end
end
