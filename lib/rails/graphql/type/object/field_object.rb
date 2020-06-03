# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The introspection object for a field on objects and interfaces
      class Object::FieldObject < Object
        self.spec_object = true

        rename! '__Field'

        desc <<~DESC
          Fields are the elements that compose both Objects and Interfaces. Each
          field in these other objects may contain arguments and always yields
          a value of a specific type.
        DESC

        field :name,               :string,        null: false
        field :description,        :string
        field :args,               '__InputValue', full: true
        field :type,               '__Type',       null: false
        field :is_deprecated,      :boolean,       null: false
        field :deprecation_reason, :string
      end
    end
  end
end
