# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL EnumType
      #
      # Enum types, like scalar types, also represent leaf values in a GraphQL
      # type system. However Enum types describe the set of possible values.
      # See http://spec.graphql.org/June2018/#EnumTypeDefinition
      class Enum < Type
        redefine_singleton_method(:leaf_type?) { true }
        redefine_singleton_method(:enum?) { true }
        define_singleton_method(:kind) { :enum }
        self.directive_location = :enum
        self.abstract = true
      end
    end
  end
end
