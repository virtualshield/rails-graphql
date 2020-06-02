# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InterfaceType
      #
      # Interfaces represent a list of named fields and their types.
      # See http://spec.graphql.org/June2018/#InterfaceTypeDefinition
      class Interface < Type
        setup! output: true
      end
    end
  end
end
