# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Base Generator
    #
    # A module to help generators to operate
    module BaseGenerator
      TEMPALTES_PATH = '../../../generators/graphql/templates'
      APP_MODULE_NAME = Rails.application.class.name.chomp('::Application')

      def self.included(base)
        base.const_set(:APP_MODULE_NAME, APP_MODULE_NAME)
        base.send(:namespace, "graphql:#{base.name.demodulize.underscore[0..-11]}")
        base.send(:source_root, File.expand_path(TEMPALTES_PATH, __dir__))
        base.send(:class_option, :directory, type: :string,
          default: 'app/graphql',
          desc: 'Directory where generated files should be saved',
        )
      end
    end
  end
end
