# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Subscription
    #
    # A namespace for storing subscription-related objects like the provider
    # for a stream/websocket provider, and the store, for where the
    # subscriptions are stored
    module Subscription
      extend ActiveSupport::Autoload

      autoload :Store
      autoload :Provider
    end
  end
end
