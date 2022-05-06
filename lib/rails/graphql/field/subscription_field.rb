# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Subscription Field
    #
    # TODO: Finish and add description
    class Field::SubscriptionField < Field::OutputField
      redefine_singleton_method(:subscription?) { true }

      # Change the schema type of the field
      def schema_type
        :subscription
      end
    end
  end
end
