# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Directive::IncludeDirective < Directive
      self.spec_object = true

      placed_on :field, :fragment_spread, :inline_fragment

      desc 'Allows for conditional inclusion during execution as described by the if argument.'

      argument :if, :boolean, null: false, desc: <<~DESC
        When false, the underlying element will be automatically marked as null.
      DESC
    end
  end
end
