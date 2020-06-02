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

        class << self
          def of_kind
            members.first.base_type
          end

          # Unions cannot be serialized on queries
          def from_ar?(*)
            false
          end

          # Just to ensure the compatibility with other outputs
          def from_ar(*)
          end

          # Checks if the returned value is a member of the union
          # TODO: We need a way to get the +__typename+ in order to do this
          # checking. Maybe we will have a 2nd argument for all +valid_output?+
          # (if so, add to the +valid_input?+ as well to keep the pattern)
          def valid_output?(value)
            # TODO: Implement!
          end

          # Since the object was already serialized, just return the result
          def to_json(value)
            value
          end

          # Since the object was already serialized, just return the result
          def to_hash(value)
            value
          end

          # Use this method to add members to the union
          def append(*others)
            return if others.blank?

            checker = others.flatten.map(&:base_type).uniq
            raise ArgumentError, <<~MSG unless checker.size === 1
              All the union members must be of the same base class.
            MSG

            check_types = members? ? members.first.base_type : VALID_MEMBER_TYPES
            raise ArgumentError, <<~MSG unless (check_types & checker).size === 1
              A union cannot contain members of different base classes.
            MSG

            members.merge(others)
          end

          # Check if the union definition is valid
          def validate!
            size = members.lazy.map(&:base_type).uniq.force.size
            raise ArgumentError, <<~MSG unless size.eql?(1)
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
