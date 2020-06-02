# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL ObjectType
      #
      # Objects represent a list of named fields, each of which yield a value of
      # a specific type.
      # See http://spec.graphql.org/June2018/#ObjectTypeDefinition
      class Object < Type
        setup! output: true
      end
    end
  end
end
