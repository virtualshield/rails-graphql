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
        setup! output: true

        # The list of accepted classes for members
        VALID_MEMBER_TYPES = [Type::Object].freeze

        # Define the methods for accessing the members attribute
        inherited_collection :members

        # The purpose of instantiating an interface is to have access to its
        # public methods. It then runs from the strategy perspective, pointing
        # out any other methods to the manually set event
        delegate_missing_to :event
        attr_reader :event

        class << self
          # Return the base type of the objects on this union
          def of_kind
            members.first.base_type
          end

          # Check if the other type is equivalent by checking if the type is
          # member of any of this union members
          def =~(other)
            super || all_members.any? { |item| other =~ item }
          end

          # Use this method to add members to the union
          def append(*others)
            return if others.blank?

            others.flatten!
            others.map! do |item|
              next item unless item.is_a?(Symbol)
              GraphQL.type_map.fetch(item, namespaces: namespaces)
            end

            checker = others.lazy.map { |item| item.try(:base_type) }.uniq.force
            raise ArgumentError, <<~MSG.squish unless checker.size === 1
              All the union members must be of the same base class.
            MSG

            check_types = members? ? [members.first.base_type] : VALID_MEMBER_TYPES
            raise ArgumentError, <<~MSG.squish unless (check_types & checker).size === 1
              A union cannot contain members of different base classes.
            MSG

            members.concat(others)
          end

          # Check if the union definition is valid
          def validate!(*)
            super if defined? super

            members = all_members
            raise ArgumentError, <<~MSG.squish unless members.size >= 1
              A union must contain at least one member.
            MSG

            size = members.lazy.map(&:base_type).uniq.force.size
            raise ArgumentError, <<~MSG.squish unless size.eql?(1)
              All the members of the union must contain the same base class.
            MSG
          end

          def inspect # :nodoc:
            <<~INFO.squish + '>'
              #<GraphQL::Union #{gql_name}
              (#{all_members.size})
              {#{all_members.map(&:gql_name).join(' | ')}}
            INFO
          end
        end
      end
    end
  end
end
