# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Base Generator
    #
    # A module to help generators to operate
    module BaseGenerator
      TEMPALTES_PATH = '../../../generators/graphql/templates'

      def self.included(base)
        base.send(:namespace, "graphql:#{base.name.demodulize.underscore[0..-11]}")
        base.send(:source_root, File.expand_path(TEMPALTES_PATH, __dir__))
        base.send(:class_option, :directory,
          type: :string,
          default: 'app/graphql',
          desc: 'Directory where generated files should be saved',
        )
      end

      protected

        def app_module_name
          require File.expand_path('config/application', destination_root)
          Rails.application.class.name.chomp('::Application')
        end
    end
  end
end
