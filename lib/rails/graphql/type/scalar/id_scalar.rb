# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The ID scalar type represents a unique identifier, often used to
      # refetch an object or as the key for a cache. The ID type is serialized
      # in the same way as a +StringScalar+.
      #
      # See http://spec.graphql.org/June2018/#sec-ID
      class Scalar::IdScalar < Scalar
        redefine_singleton_method(:gql_name) { 'ID' }
        self.spec_object = true

        desc <<~DESC
          The ID scalar type represents a unique identifier and it is serialized in the same
          way as a String.
        DESC

        class << self
          def to_hash(value)
            value = value.to_s unless value.is_a?(String)
            value = value.encode(Encoding::UTF_8) unless value.encoding.eql?(Encoding::UTF_8)
            value
          end
        end
      end
    end
  end
end
