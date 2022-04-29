# frozen_string_literal: true

require 'rails/railtie'
require 'action_controller'
require 'action_controller/railtie'

module Rails # :nodoc:
  module GraphQL # :nodoc:
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

      # Ensure a valid logger
      initializer 'graphql.logger' do
        ActiveSupport.on_load(:graphql) do |app|
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
          GraphQL::LogSubscriber.backtrace_cleaner = ::Rails.backtrace_cleaner
        end
      end

      # Add reloader ability for files under 'app/graphql'
      # TODO: Maybe improve to use rails auto loader
      initializer 'graphql.reloader' do
        Rails::GraphQL.eager_load!
        ActiveSupport::Reloader.to_prepare do
          Rails::GraphQL.type_map.use_checkpoint!
          Rails::GraphQL.reload_ar_adapters!

          Object.send(:remove_const, :GraphQL) if Object.const_defined?(:GraphQL)

          load "#{__dir__}/shortcuts.rb"

          $LOAD_PATH.each do |path|
            next unless path =~ %r{\/app\/graphql$}
            Dir.glob("#{path}/**/*.rb").sort.each(&method(:load))
          end

          GraphQL::Source.send(:build_pending!)
        end
      end

      # initializer "active_record.set_reloader_hooks" do
      #   ActiveSupport.on_load(:active_record) do
      #     ActiveSupport::Reloader.before_class_unload do
      #       if ActiveRecord::Base.connected?
      #         ActiveRecord::Base.clear_cache!
      #         ActiveRecord::Base.clear_reloadable_connections!
      #       end
      #     end
      #   end
      # end
    end
  end
end
