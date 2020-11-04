# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Spec Skip Directive
    #
    # Allow skipping fields given an +if+ condition
    class Directive::SkipDirective < Directive
      self.spec_object = true

      desc 'Allows for conditional exclusion during execution as described by the if argument.'

      placed_on :field, :fragment_spread, :inline_fragment

      argument :if, :boolean, null: false, desc: <<~DESC
        When true, the underlying element will be automatically marked as null.
      DESC

      on :attach do |source|
        source.invalidate! if args[:if]
      end
    end
  end
end
