# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL Assigned ObjectType
      #
      # A base object class that is associated with a single Ruby class object,
      # which means that valid outputs are only those that the value is an
      # instance of the assigned class or its children classes.
      class Object::AssignedObject < Object
        extend Helpers::WithAssignment

        self.base_object = true
        self.abstract = true

        class << self
          # Check if a given value is a valid non-serialized output
          def valid_member?(value)
            assigned_to.present? && value.is_a?(assigned_class)
          end
        end
      end
    end
  end
end
