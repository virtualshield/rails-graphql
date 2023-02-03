# frozen_string_literal: true

module GraphQL
  base = ActionController::Base
  base = ApplicationController if defined?(ApplicationController)

  BaseController = Class.new(base) do
    include ::Rails::GraphQL::Controller

    skip_before_action :verify_authenticity_token

    helper_method :graphiql_mode, :graphiql_url, :graphiql_channel

    def graphiql
      render 'graphql/graphiql', layout: false
    end

    protected

      # Either +fetch+ or +cable+
      def graphiql_mode
        :fetch
      end

      # Either +/graphql+ or +/cable+
      def graphiql_url
        graphiql_mode == :fetch ? '/graphql' : '/cable'
      end

      # The name of the base channel
      def graphiql_channel
        'GraphQL::BaseChannel'
      end
  end
end
