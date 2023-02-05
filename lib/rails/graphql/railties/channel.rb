# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Channel
    #
    # The channel helper methods that allow GraphQL to be performed on an
    # Action Cable channel. It also provides structure fro working with
    # subscriptions
    module Channel
      extend ActiveSupport::Concern

      included do
        # Each channel is assigned to a GraphQL schema on which the requests
        # will be performed from. It can be a string or the class
        class_attribute :gql_schema, instance_accessor: false

        # Set it up a callback after unsubscribed so that all the subscriptions
        # can be properly unsubscribed
        after_unsubscribe :gql_clear_subscriptions
      end

      # The default action of the helper to perform GraphQL requests. Any other
      # action cab be added and use the granular methods here provided
      def execute(data)
        transmit(gql_request_response(data))
      end

      protected

        # Identifies if the received request within +data+ should be threated as
        # a compiled request
        def gql_compiled_request?(*)
          false
        end

        # Get the response of a request withing the given +data+
        def gql_request_response(data)
          xargs = gql_params(data)
          schema, context, query = xargs.extract!(:schema, :context, :query).values

          request = gql_request(schema)
          request.context = context
          request.execute(query, **xargs)

          gql_merge_subscriptions(request)
          gql_response(request)
        end

        # Merge the subscriptions in this channel and the ones that were added
        # by the last request
        def gql_merge_subscriptions(request)
          gql_subscriptions.merge!(request.subscriptions)
        end

        # Properly format the response of the provided +request+ so it can be
        # transmitted
        def gql_response(request)
          { result: request.response.as_json, more: request.subscriptions? }
        end

        # Build the necessary params from the provided data
        def gql_params(data)
          cache_key = gql_query_cache_key(
            data['query_cache_key'],
            data['query_cache_version'],
          )

          {
            query: data['query'],
            origin: self,
            variables: gql_variables(data),
            operation_name: data['operation_name'] || data['operationName'],
            compiled: gql_compiled_request?(data),
            context: gql_context(data),
            schema: gql_schema(data),
            hash: cache_key,
            as: :hash,
          }
        end

        # The instance of a GraphQL request. It can't simply perform using
        # +execute+, because it is important to check if any subscription was
        # generated
        def gql_request(schema = gql_schema)
          @gql_request ||= ::Rails::GraphQL::Request.new(schema)
        end

        # Get the cache key of the query for persisted queries
        def gql_query_cache_key(key = nil, version = nil)
          CacheKey.new(key, version) if key.present?
        end

        # The schema on which the requests will be performed from
        def gql_schema(*)
          schema = self.class.gql_schema
          schema = schema.constantize if schema.is_a?(String)
          schema ||= gql_application_default_schema
          return schema if schema.is_a?(Module) && schema < ::Rails::GraphQL::Schema

          raise ExecutionError, (+<<~MSG).squish
            Unable to find a valid schema for #{self.class.name},
            defined value: #{schema.inspect}.
          MSG
        end

        # Get the GraphQL context for a requests
        # +ActionCable::Channel::Base#extract_action+
        def gql_context(data)
          { action: (data['action'] || :receive).to_sym }
        end

        # Get the GraphQL variables for a request
        def gql_variables(data, variables = nil)
          variables ||= data['variables']

          case variables
          when ::ActionController::Parameters then variables.permit!.to_h
          when String then variables.present? ? JSON.parse(variables) : {}
          when Hash   then variables
          else {}
          end
        end

        # The list of ids of subscription and to which field they are
        # associated with
        def gql_subscriptions
          @gql_subscriptions ||= {}
        end

        # Remove all subscriptions
        def gql_clear_subscriptions
          gql_remove_subscription(*gql_subscriptions.keys) unless gql_subscriptions.empty?
        end

        # Remove one or more subscriptions
        def gql_remove_subscriptions(*sids)
          gql_schema.remove_subscriptions(*sids)
        end

        alias gql_remove_subscription gql_remove_subscriptions

      private

        # Find the default application schema
        def gql_application_default_schema
          app_class = Rails.application.class
          source_name = app_class.respond_to?(:module_parent_name) \
            ? :module_parent_name \
            : :parent_name

          klass = "::GraphQL::#{app_class.public_send(source_name)}Schema".constantize
          self.class.gql_schema = klass
        end
    end
  end
end
