# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Base Generator
    #
    # A module to help generators to operate
    module BaseGenerator
      TEMPALTES_PATH = '../../../generators/graphql/templates'.freeze

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

          app_class = Rails.application.class
          source_name = app_class.respond_to?(:module_parent_name) \
            ? :module_parent_name \
            : :parent_name

          app_class.send(source_name)
        end
    end
  end
end
