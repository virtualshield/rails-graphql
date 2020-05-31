# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL UnionType
      #
      # Unions represent an object that could be one of a list of GraphQL
      # Object types.
      # See http://spec.graphql.org/June2018/#UnionTypeDefinition
      class Union < Type
        redefine_singleton_method(:input_type?) { false }
        redefine_singleton_method(:union?) { true }
        define_singleton_method(:kind) { :union }
        self.directive_location = :union
        self.spec_object = true
        self.abstract = true

        # The list of accepted classes for members
        VALID_MEMBER_TYPES = [Type::Enum, Type::Input, Type::Object].freeze

        # Define the methods for accessing the members attribute
        inherited_collection :members

        class << self
          def kind
            members.first.base_type if valid?
          end

          def valid?
            @valid ||= members.lazy.map(&:base_type).uniq.force.size.eql?(1)
          end

          def append(*others)
            return if others.blank?

            # TODO: Change to a better exception type
            checker = others.flatten.map(&:base_type).uniq
            raise 'All the union members must be of the same base type' \
              if checker.size != 1

            # TODO: Change to a better exception type
            check_types = members? ? @members.first.base_type : VALID_MEMBER_TYPES
            raise 'The given base type cannot be assigned to this union' \
              if (check_types & checker).size != 1

            self.members.merge(others)
          end
        end
      end
    end
  end
end
