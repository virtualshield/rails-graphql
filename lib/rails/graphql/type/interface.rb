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
      # serializing process.
      class Interface < Type
        extend Helpers::WithFields

        setup! output: true

        self.field_type = Field::OutputField

        # The purpose of instantiating an interface is to have access to its
        # public methods. It then runs from the strategy perspective, pointing
        # out any other methods to the manually set event
        delegate_missing_to :@event
        attr_reader :event

        class << self
          # Stores the list of types associated with the interface so it can
          # be used during the execution step to find the right object type
          def types
            @types ||= Set.new
          end

          # Get the list of all inherited-aware associated types
          def all_types
            (superclass.try(:all_types) || []) + (@types&.to_a || [])
          end

          # Check if the other type is equivalent, by checking if the other is
          # an object and the object implements this interface
          def =~(other)
            super || (other.object? && other.implements?(self))
          end

          # When attaching an interface to an object, copy the fields and add to
          # the list of types. Pre-existing same-named fields with are not
          # equivalent produces an exception.
          def implemented(object)
            fields.each do |name, field|
              invalid = object.field?(name) && !(object.fields[name] =~ field)
              raise ArgumentError, <<~MSG.squish if invalid
                The "#{object.gql_name}" object already has a "#{field.gql_name}" field and it
                is not equivalent to the one defined on the "#{gql_name}" interface.
              MSG

              object.proxy_field(field)
            end

            types << object
          end

          def inspect # :nodoc:
            fields = @fields.each_value.map(&:inspect)
            fields = fields.presence && "{#{fields.join(', ')}}"
            "#<GraphQL::Interface #{gql_name} #{fields}>"
          end

          # Check if the given object is properly implementing this interface
          def validate(*)
            # Don't validate interfaces since the fields are copied and
            # the interface might have broken field types due to namespaces
          end
        end
      end
    end
  end
end
