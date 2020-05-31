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
        redefine_singleton_method(:input_type?) { false }
        redefine_singleton_method(:object?) { true }

        self.directive_location = :object
        self.spec_object = true
        self.abstract = true
      end
    end
  end
end
