module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Directive
    #
    # This is the base object for directives definition
    # See: http://spec.graphql.org/June2018/#DirectiveDefinition
    class Directive
      extend ActiveSupport::Autoload
      extend GraphQL::NamedDefinition

      VALID_LOCATIONS = %i[
        query mutation subscription field
        fragment_definition fragment_spread inline_fragment

        schema scalar object field_definition interface union enum enum_value
        argument_definition input_object input_field_definition
      ].freeze

      ##
      # The given description of the directive
      class_attribute :description, instance_writer: false

      ##
      # The list of locations where the given directive can be used
      class_attribute :locations, instance_writer: false, default: Set.new
      private :locations=

      class << self
        # A secure way to specify the locations of a given directive
        def for(*values)
          values = values.flatten.map(&:to_sym)
          invalid = values - VALID_LOCATIONS
          return self.locations += values if invalid.empty?

          # TODO: Add a correct exception here
          raise "Invalid locations for @#{gql_name}: #{invalid.to_sentence}"
        end
      end
    end
  end
end
