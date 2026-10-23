# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'
require 'active_support/ordered_options'

module Rails
  module GraphQL
    module Configurable
      def config
        @config ||= begin
          parent = respond_to?(:superclass) ? superclass : nil
          parent.respond_to?(:config) ? parent.config.deep_dup : ActiveSupport::InheritableOptions.new
        end
      end

      def config=(value)
        @config = value
      end

      def configure
        yield(config)
      end
    end
  end
end
