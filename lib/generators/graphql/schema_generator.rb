# frozen_string_literal: true

require 'rails/generators/base'

module GraphQL
  module Generators
    class SchemaGenerator < Rails::Generators::Base # :nodoc:
      include Rails::GraphQL::BaseGenerator

      desc 'Add a new GraphQL schema'
      argument :name, type: :string, optional: true

      def create_schema_file
        template 'schema.erb', "#{options[:directory]}/#{schema_name.underscore}.rb"
      end

      def schema_name
        @schema_name ||= "#{options[:name].presence || app_module_name}Schema"
      end
    end
  end
end
