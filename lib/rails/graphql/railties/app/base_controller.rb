# frozen_string_literal: true

module GraphQL
  base = ActionController::Base
  base = ApplicationController if defined?(ApplicationController)

  BaseController = Class.new(base) do
    include ::Rails::GraphQL::Controller

    skip_before_action :verify_authenticity_token
  end
end
