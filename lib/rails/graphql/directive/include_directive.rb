# frozen_string_literal: true

module Rails
  module GraphQL
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

      # TODO: On attach does not covers default value per operation variable scenario
      on(:attach) do |source|
        source.skip! unless args[:if]
      end
    end
  end
end
