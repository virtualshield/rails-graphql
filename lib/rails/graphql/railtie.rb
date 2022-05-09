# frozen_string_literal: true

require 'rails/railtie'
require 'action_controller'
require 'action_controller/railtie'

module Rails
  module GraphQL
    # = Rails GraphQL Railtie
    #
    # Rails integration and configuration
    class Railtie < Rails::Railtie
      config.eager_load_namespaces << Rails::GraphQL
      config.graphql = GraphQL.config

      rake_tasks do
        load 'rails/graphql.rake'
      end

      runner do
        require_relative './schema'
      end

      console do
        config.graphql.enable_string_collector = false
        config.graphql.default_response_format = :hash
      end

      # Ensure a valid logger
      initializer 'graphql.logger' do |app|
        ActiveSupport.on_load(:graphql) do
          return if config.logger.present?

          logger = ::Rails.logger
          if logger.respond_to?(:tagged)
            config.logger = logger
          else
            config.logger = ActiveSupport::TaggedLogging.new(logger)
          end
        end
      end

      # Expose GraphQL runtime to controller for logging
      initializer 'graphql.log_runtime' do
        require_relative './railties/controller_runtime'
        ActiveSupport.on_load(:action_controller) do
          include GraphQL::ControllerRuntime
        end
      end

      # Clean up GraphQL params from logger
      initializer 'graphql.params_cleanup' do
        key = 'start_processing.action_controller'
        ActiveSupport::Notifications.subscribe(key) do |*, payload|
          payload[:params].except!(*config.graphql.omit_parameters) \
            if payload[:headers]['action_controller.instance'].is_a?(GraphQL::Controller)
        end
      end

      # Copy filter params when they are not exclusively set for GraphQL
      initializer 'graphql.params_filter' do |app|
        config.after_initialize do
          config.graphql.filter_parameters ||= app.config.filter_parameters
        end
      end

      # Backtrace cleaner for removing gem paths
      initializer 'graphql.backtrace_cleaner' do
        require_relative './railties/log_subscriber'
        ActiveSupport.on_load(:graphql) do
          LogSubscriber.backtrace_cleaner = ::Rails.backtrace_cleaner
        end
      end

      # Add the GraphQL Global ID serializer to active job serializers
      initializer 'graphql.global_id' do
        ActiveSupport.on_load(:active_job) do
          ActiveJob::Serializers.add_serializers(Rails::GraphQL::GlobalID::Serializer)
        end
      end

      # Attempt to auto load the base schema as a dependency of the type map
      initializer 'graphql.auto_base_schema' do |app|
        ActiveSupport.on_load(:graphql) do
          file = app.railtie_name.sub(/_application$/, '_schema')
          path = app.root.join('app').join('graphql').join(file)
          GraphQL.type_map.add_dependencies(path.to_s, to: :base) if path.sub_ext('.rb').exist?
        end
      end
    end
  end
end
