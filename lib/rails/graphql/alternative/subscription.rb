# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Alternative Subscription
    #
    # Same as it's parent class, but for subscription
    class Alternative::Subscription < Alternative::Query
      redefine_singleton_method(:type_field_class) { :subscription }
      self.abstract = true

      class << self
        delegate :scope, :trigger_for, :trigger, :unsubscribe_from, :unsubscribe,
          to: :@field, allow_nil: true
      end
    end
  end
end
