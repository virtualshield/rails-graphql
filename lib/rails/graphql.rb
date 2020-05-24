# frozen_string_literal: true

require 'active_support'

require 'rails/graphql/version'
require 'rails/graphql/railtie'

module Rails # :nodoc:
  module GraphQL
    extend ActiveSupport::Autoload

    autoload :Core

    autoload :GraphiQL

    class << self
      ##
      # Initiate a simple config object. It also supports a block which
      # simplifies bulk configuration.
      # See Also https://github.com/rails/rails/blob/master/activesupport/lib/active_support/ordered_options.rb
      def config
        @config ||= begin
          config = ActiveSupport::OrderedOptions.new
          config.graphiql = ActiveSupport::OrderedOptions.new
          config
        end

        yield(@config) if block_given?

        @config
      end

      ##
      # Simple import configurations defined using rails +config.graphql+ to
      # easy-to-use accessors on the
      # {Schema}[rdoc-ref:Rails::GraphQL::Core] class.
      def set_configs!
        config.each { |k, v| Core.send "#{k}=", v }
      end

      # def eager_load!
      #   super
      # end
    end
  end
end
