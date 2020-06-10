# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # Bigint basically removes the limit of the value, but it serializes as
      # a string so it won't go against the spec
      class Enum::DirectiveLocationEnum < Enum
        self.spec_object = true

        rename! '__DirectiveLocation'

        desc 'The valid locations that a directive may be placed.'

        %w[QUERY MUTATION SUBSCRIPTION FIELD FRAGMENT_DEFINITION
          FRAGMENT_SPREAD INLINE_FRAGMENT].each do |value|
          desc = value.downcase.tr('_', ' ')
          add(value, desc: "Mark as a executable directive usable on #{desc} objects.")
        end

        %w[SCHEMA SCALAR OBJECT FIELD_DEFINITION ARGUMENT_DEFINITION INTERFACE UNION
          ENUM ENUM_VALUE INPUT_OBJECT INPUT_FIELD_DEFINITION].each do |value|
          desc = value.downcase.tr('_', ' ')
          desc = "Mark as a type system directive usable on #{desc} definitions."
          add(value, desc: desc.gsub(/definition definitions\.$/, 'definitions.'))
        end
      end
    end
  end
end
