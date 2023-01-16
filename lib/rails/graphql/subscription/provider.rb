# frozen_string_literal: true

module Rails
  module GraphQL
    module Subscription
      # = GraphQL Subscription Provider
      #
      # Subscription provider holds all the possible options for handlers of
      # subscriptions, which all should inherit from Provider::Base
      module Provider
        extend ActiveSupport::Autoload

        autoload :Base
        autoload :ActionCable
      end
    end
  end
end
