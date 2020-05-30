# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Schema
    #
    # This is a pure representation of a GraphQL schema.
    # See: http://spec.graphql.org/June2018/#SchemaDefinition
    class Schema
      include GraphQL::Core
    end

    ActiveSupport.run_load_hooks(:graphql, Schema)
  end
end
