# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Bigint basically removes the limit of the value, but it serializes as
      # a string so it won't go against the spec
      class Enum::DirectiveLocationEnum < Enum
        self.spec_object = true

        rename! '__DirectiveLocation'

        desc 'The valid locations that a directive may be placed.'

        Directive::EXECUTION_LOCATIONS.each do |value|
          name = value.to_s.upcase
          desc = value.to_s.tr('_', ' ')
          add(name, desc: "Mark as a executable directive usable on #{desc} objects.")
        end

        Directive::DEFINITION_LOCATIONS.each do |value|
          name = value.to_s.upcase
          desc = value.to_s.tr('_', ' ')
          desc = "Mark as a type system directive usable on #{desc} definitions."
          add(name, desc: desc.sub('definition definitions.', 'definitions.'))
        end
      end
    end
  end
end
