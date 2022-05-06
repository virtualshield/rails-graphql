# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The introspection object for an enum value
      class Object::EnumValueObject < Object
        self.spec_object = true

        rename! '__EnumValue'

        desc <<~DESC
          One of the values of an Enum object. It is unique within the Enum set
          of values. It's a string representation, not a numeric representation,
          of a value kept as all caps (ie. ONE_VALUE).
        DESC

        field :name,               :string,  null: false
        field :description,        :string
        field :is_deprecated,      :boolean, null: false
        field :deprecation_reason, :string
      end
    end
  end
end
