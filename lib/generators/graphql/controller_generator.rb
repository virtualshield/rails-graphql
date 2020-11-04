# frozen_string_literal: true

require 'rails/generators/base'

module GraphQL
  module Generators
    class ControllerGenerator < Rails::Generators::Base # :nodoc:
      include Rails::GraphQL::BaseGenerator

      desc 'Add a new controller that operates with GraphQL'
      argument :name, type: :string, optional: true

      def create_controller_file
        template 'controller.erb', "app/controllers/#{controller_name.underscore}.rb"
      end

      def controller_name
        @controller_name ||= (options[:name].presence&.classify || 'GraphQL') + 'Controller'
      end
    end
  end
end
