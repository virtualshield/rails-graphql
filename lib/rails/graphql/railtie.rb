# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = Rails GraphQL Railtie
    class Railtie < Rails::Railtie # :nodoc:
      config.graphql = GraphQL.config

      # config.action_dispatch.rescue_responses.merge!(
      #   "ActiveRecord::RecordNotFound"   => :not_found,
      #   "ActiveRecord::StaleObjectError" => :conflict,
      #   "ActiveRecord::RecordInvalid"    => :unprocessable_entity,
      #   "ActiveRecord::RecordNotSaved"   => :unprocessable_entity
      # )

      rake_tasks do
        load 'rails/graphql.rake'
      end

      # # Make it output to STDERR.
      # console do |app|
      #   require "active_record/railties/console_sandbox" if app.sandbox?
      #   require "active_record/base"
      #   unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDERR, STDOUT)
      #     console = ActiveSupport::Logger.new(STDERR)
      #     Rails.logger.extend ActiveSupport::Logger.broadcast console
      #   end
      #   ActiveRecord::Base.verbose_query_logs = false
      # end

      runner do
        require 'rails/graphql/schema'
      end

      # initializer 'active_record.logger' do
      #   ActiveSupport.on_load(:active_record) { self.logger ||= ::Rails.logger }
      # end

      initializer 'graphql.set_configs' do |app|
        ActiveSupport.on_load(:graphql) do
          Rails::GraphQL.set_configs!
        end
      end

      # # Expose database runtime to controller for logging.
      # initializer "active_record.log_runtime" do
      #   require "active_record/railties/controller_runtime"
      #   ActiveSupport.on_load(:action_controller) do
      #     include ActiveRecord::Railties::ControllerRuntime
      #   end
      # end

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
