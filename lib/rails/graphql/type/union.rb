# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL UnionType
      #
      # Unions represent an object that could be one of a list of GraphQL
      # Object types.
      # See http://spec.graphql.org/June2018/#UnionTypeDefinition
      class Union < Type
        redefine_singleton_method(:input_type?) { false }
        redefine_singleton_method(:union?) { true }
        define_singleton_method(:kind) { :union }
        self.directive_location = :union
        self.abstract = true
      end
    end
  end
end
