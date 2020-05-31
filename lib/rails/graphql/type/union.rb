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

        self.directive_location = :union
        self.spec_object = true
        self.abstract = true

        # The list of accepted classes for members
        VALID_MEMBER_TYPES = [Type::Enum, Type::Input, Type::Object].freeze

        # Define the methods for accessing the members attribute
        inherited_collection :members

        class << self
          def of_kind
            members.first.base_type if valid?
          end

          def valid?
            @valid ||= members.lazy.map(&:base_type).uniq.force.size.eql?(1)
          end

          def append(*others)
            return if others.blank?

            checker = others.flatten.map(&:base_type).uniq
            raise ArgumentError, <<~MSG unless checker.size === 1
              All the union members must be of the same base type.
            MSG

            check_types = members? ? @members.first.base_type : VALID_MEMBER_TYPES
            raise ArgumentError, <<~MSG unless (check_types & checker).size === 1
              A union cannot contain members of different base types.
            MSG

            self.members.merge(others)
          end
        end
      end
    end
  end
end
