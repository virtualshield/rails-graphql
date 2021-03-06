# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The String scalar type represents textual data, represented as UTF-8
      # character sequences.
      #
      # See http://spec.graphql.org/June2018/#sec-String
      class Scalar::StringScalar < Scalar
        self.spec_object = true

        desc <<~DESC
          The String scalar type represents textual data, represented as UTF‐8 character
          sequences.
        DESC

        class << self
          def as_json(value)
            value = value.to_s unless value.is_a?(String)
            value = value.encode(Encoding::UTF_8) unless value.encoding.eql?(Encoding::UTF_8)
            value
          end
        end
      end
    end
  end
end
