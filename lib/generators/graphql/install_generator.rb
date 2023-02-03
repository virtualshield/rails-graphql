# frozen_string_literal: true

require 'rails/generators/base'

module GraphQL
  module Generators
    class InstallGenerator < Rails::Generators::Base # :nodoc:
      include Rails::GraphQL::BaseGenerator

      desc 'Add an initial setup to your application'

      class_option :schema, type: :string, optional: true,
        default: "#{APP_MODULE_NAME}Schema",
        desc: 'A name for the schema'

      class_option :skip_routes, type: :boolean,
        default: false,
        desc: 'Add some initial routes'

      class_option :skip_keeps, type: :boolean,
        default: false,
        desc: 'Skip .keep files'

      def create_config_file
        template 'config.rb', 'config/initializers/graphql.rb'
      end

      def create_schema
        invoke 'graphql:schema'
      end

      def create_keep_files
        return if options[:skip_keeps]

        %w[
          directives fields sources enums inputs interfaces object
          scalars unions queries mutations subscriptions
        ].each { |folder| create_file("#{options[:directory]}/#{folder}/.keep") }
      end

      def add_routes
        return if options[:skip_routes]
        route('get  "/graphql/describe", to: "graphql/base#describe"')
        route('get  "/graphiql",         to: "graphql/base#graphiql"')
        route('post "/graphql",          to: "graphql/base#execute"')
      end
    end
  end
end
