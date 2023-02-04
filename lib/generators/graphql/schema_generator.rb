# frozen_string_literal: true

require 'rails/generators/base'

module GraphQL
  module Generators
    class SchemaGenerator < Rails::Generators::Base # :nodoc:
      include Rails::GraphQL::BaseGenerator

      desc 'Add a new GraphQL schema'

      argument :schema, type: :string, optional: true,
        default: "#{APP_MODULE_NAME}Schema",
        desc: 'A name for the schema'

      def create_schema_file
        template 'schema.erb', "#{options[:directory]}/#{schema_name.underscore}.rb"
      end

      private

        def schema_name
          @schema_name ||= options.fetch(:schema, "#{APP_MODULE_NAME}Schema")
        end
    end
  end
end
