# frozen_string_literal: true

module GraphQL
  base = ActionCable::Channel::Base
  base = ApplicationCable::Channel if defined?(ApplicationCable::Channel)

  BaseChannel = Class.new(base) do
    include ::Rails::GraphQL::Channel
  end
end
