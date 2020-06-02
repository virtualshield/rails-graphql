# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InterfaceType
      #
      # Interfaces represent a list of named fields and their types.
      # See http://spec.graphql.org/June2018/#InterfaceTypeDefinition
      #
      # This class doesn't implements +valid_output?+ nor any of the output like
      # methods because the Object class that uses interface already fetches
      # all the fields for its composition and does the validating and
      # serealizing process.
      class Interface < Type
        extend Helpers::WithFields

        setup! output: true

        self.valid_field_types = [Type::Enum, Type::Object, Type::Scalar].freeze
        self.field_types = [Field::OutputField].freeze

        class << self
          def inspect # :nodoc:
            parts = fields.each_value.map(&:inspect)
            parts = parts.presence && "{#{parts.join(', ')}}"
            "#<GraphQL::Interface #{gql_name} #{parts}>"
          end
        end
      end
    end
  end
end
