# frozen_string_literal: true

module Rails
  module GraphQL
    # Several alternatives to declare GraphQL objects
    module Alternative
      extend ActiveSupport::Autoload

      autoload :Query
      autoload :Mutation
      autoload :Subscription

      autoload_at "#{__dir__}/alternative/field_set" do
        autoload :FieldSet
        autoload :MutationSet
        autoload :SubscriptionSet
      end
    end
  end
end
