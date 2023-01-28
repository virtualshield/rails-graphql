# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Spec Specified By Directive
    #
    # Provides a scalar specification URL for specifying the behavior of
    # custom scalar types.
    class Directive::SpecifiedByDirective < Directive
      self.spec_object = true

      placed_on :scalar

      desc <<~DESC
        A built-in directive used within the type system definition language to provide
        a scalar specification URL for specifying the behavior of custom scalar types.
      DESC

      argument :url, :string, null: false, desc: <<~DESC
        Point to a human-readable specification of the data format.
      DESC
    end
  end
end
