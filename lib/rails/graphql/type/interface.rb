# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InterfaceType
      #
      # Interfaces represent a list of named fields and their types.
      # See http://spec.graphql.org/June2018/#InterfaceTypeDefinition
      class Interface < Type
        redefine_singleton_method(:input_type?) { false }
        redefine_singleton_method(:interface?) { true }
        define_singleton_method(:kind) { :interface }
        self.spec_object = true
        self.abstract = true
      end
    end
  end
end
