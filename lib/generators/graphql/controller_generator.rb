# frozen_string_literal: true

require 'rails/generators/base'

module GraphQL
  module Generators
    class ControllerGenerator < Rails::Generators::Base # :nodoc:
      include Rails::GraphQL::BaseGenerator

      desc 'Add a new controller that operates with GraphQL'

      class_option :name, type: :string, optional: true,
        default: "GraphQLController",
        desc: 'The name for the controller'

      def create_controller_file
        template 'controller.erb', "app/controllers/#{controller_name.underscore}.rb"
      end

      private

        def controller_name
          @controller_name ||= options.fetch(:name, 'GraphQLController').classify
        end
    end
  end
end
