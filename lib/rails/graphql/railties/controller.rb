# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Controller
    #
    # The controller helper methods that allow GraphQL to be performed on a
    # Rails Controller class.
    module Controller
      extend ActiveSupport::Concern

      REQUEST_XARGS = %i[operation_name variables context schema].freeze

      included do
        # Each controller is assigned to a GraphQL schema on which the requests
        # will be performed from. It can be a string or the class
        class_attribute :gql_schema, instance_accessor: false
      end

      # POST /execute
      def execute
        gql_request_response(gql_query)
      end

      # GET /describe
      def describe
        render plain: gql_schema.to_gql(
          with_descriptions: !params.key?(:without_descriptions),
          with_spec: !params.key?(:without_spec),
        )
      end

      protected

        # Render a response as a GraphQL request
        def gql_request_response(*args, **xargs)
          render json: gql_request(*args, **xargs)
        end

        # Execute a GraphQL request
        def gql_request(query, **xargs)
          request_xargs = REQUEST_XARGS.inject({}) do |result, setting|
            result.merge(setting => (xargs[setting] || send("gql_#{setting}")))
          end

          ::Rails::GraphQL::Request.execute(query, **request_xargs)
        end

        # The schema on which the requests will be performed from
        def gql_schema
          schema = self.class.gql_schema
          schema = schema.safe_constantize if schema.is_a?(String)
          schema ||= application_default_schema
          return schema if schema.is_a?(Module) && schema < ::Rails::GraphQL::Schema

          raise ExecutionError, <<~MSG.squish
            Unable to find a valid schema for #{self.class.name},
            defined value: #{schema.inspect}.
          MSG
        end

        # Get the GraphQL query to execute
        def gql_query
          params[:query]
        end

        # Get the GraphQL operation name
        def gql_operation_name
          params[:operationName]
        end

        # Get the GraphQL context for a requests
        def gql_context
          {}
        end

        # Get the GraphQL variables for a request
        def gql_variables(variables = params[:variables])
          case variables
          when ::ActionController::Parameters then variables.permit!.to_h
          when String then variables.present? ? JSON.parse(variables) : {}
          when Hash   then variables
          else {}
          end
        end

      private

        # Find the default application schema
        def application_default_schema
          app_class = Rails.application.class
          source_name = app_class.respond_to?(:module_parent_name) \
            ? :module_parent_name \
            : :parent_name

          klass = "::GraphQL::#{app_class.send(source_name)}Schema".constantize
          self.class.gql_schema = klass
        end
    end
  end
end
