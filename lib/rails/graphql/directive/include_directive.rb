# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Spec Include Directive
    #
    # Allow including fields only +if+ condition is true
    class Directive::IncludeDirective < Directive
      self.spec_object = true

      placed_on :field, :fragment_spread, :inline_fragment

      desc 'Allows for conditional inclusion during execution as described by the if argument.'

      argument :if, :boolean, null: false, desc: <<~DESC
        When false, the underlying element will be automatically marked as null.
      DESC

      on :attach do |source|
        source.invalidate! unless args[:if]
      end
    end
  end
end
