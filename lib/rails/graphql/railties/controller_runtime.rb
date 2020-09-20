# frozen_string_literal: true

require 'active_support/core_ext/module/attr_internal'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Controller Runtime
    #
    # Tool that calculates the runtime of a GraphQL operation. This works
    # similar to how Rails ActiveRecord calculate its execution time while
    # performing a request.
    module ControllerRuntime
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc: all
        def log_process_action(payload)
          messages, gql_runtime = super, payload[:gql_runtime]
          messages << ("GraphQL: %.1fms" % gql_runtime.to_f) if gql_runtime
          messages
        end
      end

      private
        attr_internal :gql_runtime

        def process_action(*)
          LogSubscriber.runtime = 0
          super
        end

        def append_info_to_payload(payload)
          super

          payload[:gql_runtime] = LogSubscriber.runtime if (LogSubscriber.runtime || 0) > 0
        end
    end
  end
end
