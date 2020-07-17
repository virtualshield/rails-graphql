# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Directive::AlwaysVaderDirective < Directive
      placed_on :field_definition

      desc 'Replace the value of a string with Darth Vader'

      on :finalize, during: :execution do |context|
        context.override_value('Darth Vader')
      end
    end
  end
end
