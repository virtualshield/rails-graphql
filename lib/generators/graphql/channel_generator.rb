# frozen_string_literal: true

require 'rails/generators/base'

module GraphQL
  module Generators
    class ChannelGenerator < Rails::Generators::Base # :nodoc:
      include Rails::GraphQL::BaseGenerator

      desc 'Add a new action cable channel that operates with GraphQL'

      argument :name, type: :string, optional: true,
        default: "GraphQLChannel",
        desc: 'The name for the channel'

      def create_channel_file
        template 'channel.erb', "app/channels/#{channel_name.underscore}.rb"
      end

      private

        def channel_name
          @channel_name ||= options.fetch(:name, 'GraphQLChannel').classify
        end
    end
  end
end
