# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Type
    #
    # This is the most pure object from GraphQL. Anything that a schema can
    # define will be an extension of this class
    # See: http://spec.graphql.org/June2018/#sec-Types
    class Type
      extend ActiveSupport::Autoload
      extend GraphQL::NamedDefinition
      extend GraphQL::WithDirectives

      ##
      # A direct representation of the spec types
      KINDS = %w[Scalar Object Interface Union Enum Input].freeze
      KINDS.each { |kind| autoload kind.to_sym }

      ##
      # If a type is marked as abstract, it's then used as a base and it won't
      # appear in the introspection
      class_attribute :abstract, instance_writer: false, default: false

      ##
      # The given description of the type
      class_attribute :description, instance_writer: false

      class << self
        # Reset some class attributes, meaning that they are not cascade
        def inherited(subclass)
          subclass.abstract = false
        end

        # Fetch the list of all available types
        def all
          descendants.reject { |klass| klass.abstract? }
        end

        # Defines if the current type is a valid input type
        def input_type?
          true
        end

        # Defines if the current type is a valid output type
        def output_type?
          true
        end

        # Defines if the current type is a leaf output type
        def leaf_type?
          false
        end

        # Checks if the current type is an extension of another type
        def extension?
          !superclass.abstract?
        end

        # Defines a serie of question methods based on the kind
        KINDS.each { |kind| define_method("#{kind.downcase}?") { false } }
      end
    end
  end
end
