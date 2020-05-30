# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # A shared module for Types and Directives that enables retriving the
    # GraphQL name of an object
    module NamedDefinition
      def gql_name
        name.match(/GraphQL::(?:Type::\w+::)?([:\w]+)[A-Z][a-z]+\z/)[1].tr(':', '')
      end

      def to_sym
        gql_name.underscore.to_sym
      end
    end
  end
end
