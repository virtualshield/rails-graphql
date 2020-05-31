# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InputType
      #
      # Input defines a set of input fields; the input fields are either
      # scalars, enums, or other input objects.
      # See http://spec.graphql.org/June2018/#InputObjectTypeDefinition
      class Input < Type
        redefine_singleton_method(:kind_enum) { 'INPUT_OBJECT' }
        redefine_singleton_method(:output_type?) { false }
        redefine_singleton_method(:input?) { true }
        define_singleton_method(:kind) { :input }
        self.directive_location = :input_object
        self.spec_object = true
        self.abstract = true
      end
    end
  end
end
