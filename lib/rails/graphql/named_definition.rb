# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # A shared module for Types and Directives that enables retriving the
    # GraphQL name of an object
    module NamedDefinition
      delegate :gql_name, to: :class

      EXP = /GraphQL::(?:Type::\w+::|Directive::)?([:\w]+)[A-Z][a-z]+\z/.freeze

      def gql_name
        name.match(EXP)[1].tr(':', '')
      end

      def to_sym
        gql_name.underscore.to_sym
      end
    end
  end
end
