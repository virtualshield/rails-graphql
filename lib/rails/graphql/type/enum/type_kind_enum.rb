# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Bigint basically removes the limit of the value, but it serializes as
      # a string so it won't go against the spec
      class Enum::TypeKindEnum < Enum
        self.spec_object = true

        rename! '__TypeKind'

        desc <<~DESC
          The fundamental unit of any GraphQL Schema is the type.
          This enum enlist all the valid base types.
        DESC

        add 'SCALAR', desc: <<~DESC
          Scalar types represent primitive leaf values in a GraphQL type system.
        DESC

        add 'OBJECT', desc: <<~DESC
          Objects represent a list of named fields, each of which yield a value of a
          specific type.
        DESC

        add 'INTERFACE', desc: <<~DESC
          Interfaces represent a list of named fields and their types.
        DESC

        add 'UNION', desc: <<~DESC
          Unions represent an object that could be one of a list of GraphQL Object types.
        DESC

        add 'ENUM', desc: <<~DESC
          Enum types, like scalar types, also represent leaf values in a GraphQL
          type system. However Enum types describe the set of possible values.
        DESC

        add 'INPUT_OBJECT', desc: <<~DESC
          Objects represent a list of named fields, each of which yield a value of
          a specific type.
        DESC

        add 'LIST', desc: <<~DESC
          A GraphQL list is a special collection type which declares the type of
          each item in the List (referred to as the item type of the list).
        DESC

        add 'NON_NULL', desc: <<~DESC
          This type wraps an underlying type, and this type acts identically to that wrapped
          type, with the exception that null is not a valid response for the wrapping type.
        DESC
      end
    end
  end
end
