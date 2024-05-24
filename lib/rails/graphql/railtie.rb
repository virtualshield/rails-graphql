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
          config.logger ||= begin
            logger = ::Rails.logger
            logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
          end
        end
      end

      initializer 'graphql.active_record_backtrace_print' do
        if defined?(ActiveRecord)
          base = Module.new
          base.send(:define_method, :to_gql_backtrace) do
            +"#<#{self.class.name} id: #{id}>"
          end

          relation = Module.new
          relation.send(:define_method, :to_gql_backtrace) do
            +"[#<#{model.name}>](#{size})"
          end

          ActiveRecord::Base.include(base)
          ActiveRecord::Relation.include(relation)
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

      # Simply switch to hash output if rails is running on test mode
      initializer 'graphql.tests' do
        if Rails.env.test?
          config.graphql.enable_string_collector = false
          config.graphql.default_response_format = :hash
        end
      end

      # Set GraphQL cache store same as rails default cache store, unless the
      # default value is a Null Cache, then use the fallback instead
      initializer 'graphql.cache', after: :initialize_cache do
        config.graphql.cache ||= begin
          if !::Rails.cache.is_a?(::ActiveSupport::Cache::NullStore)
            ::Rails.cache
          elsif config.graphql.cache_fallback.is_a?(Proc)
            config.graphql.cache_fallback.call
          else
            config.graphql.cache_fallback
          end
        end
      end

      # Properly setup how GraphQL reload itself
      # TODO: Check proper support for Rails engines
      initializer 'graphql.reloader', before: :load_config_initializers do |app|
        next unless (path = app.root.join('app', 'graphql')).exist?

        children = config.graphql.paths.to_a.join(',')
        autoloader = app.respond_to?(:autoloaders) ? app.autoloaders : Rails.autoloaders
        autoloader = autoloader.main

        ActiveSupport::Dependencies.autoload_paths.delete(path.to_s)
        autoloader.collapse(path.glob("**/{#{children}}").select(&:directory?))
        autoloader.push_dir(path, namespace: ::GraphQL)
        config.watchable_dirs[path.to_s] = [:rb]

        autoloader.on_unload do |_, value, _|
          value.unregister! if value.is_a?(Helpers::Unregisterable)
        end
      end
    end
  end
end
