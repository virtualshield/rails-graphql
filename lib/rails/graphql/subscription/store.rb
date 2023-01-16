# frozen_string_literal: true

module Rails
  module GraphQL
    module Subscription
      # = GraphQL Subscription Store
      #
      # Subscription store holds all the possible options for storing the
      # subscriptions, allowing to segmentation by field, variables, and several
      # other things according to the necessity
      module Store
        extend ActiveSupport::Autoload

        autoload :Base
        autoload :Memory
      end
    end
  end
end
