# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Controller
    #
    # The controller helper methods that allow GraphQL to be performed on a
    # Rails Controller class.
    module Controller
      extend ActiveSupport::Concern

      REQUEST_XARGS = %i[operation_name variables context schema query_cache_key].freeze
      DESCRIBE_HEADER = <<~TXT.freeze
        """
        Use the following HTTP params to modify this result:
          without_descriptions => Remove all descriptions
          without_spec => Remove all types from GraphQL spec
        """
      TXT

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
        render plain: DESCRIBE_HEADER + gql_describe_schema
      end

      protected

        # Render a response as a GraphQL request
        def gql_request_response(*args, **xargs)
          render json: gql_request(*args, **xargs)
        end

        # Shows a text representation of the schema
        def gql_describe_schema
          gql_schema_header + gql_schema.to_gql(
            with_descriptions: !params.key?(:without_descriptions),
            with_spec: !params.key?(:without_spec),
          )
        end

        # Execute a GraphQL request
        def gql_request(query, **xargs)
          request_xargs = REQUEST_XARGS.each_with_object({}) do |setting, result|
            result[setting] = (xargs[setting] || send(:"gql_#{setting}"))
          end

          result[:hash] = result.delete(:query_cache_key)
          ::Rails::GraphQL::Request.execute(query, **request_xargs)
        end

        # Print a header of the current schema for the description process
        # TODO: Maybe add a way to detect from which file the schema is being loaded
        def gql_schema_header
          schema = self.class.gql_schema
          "# Schema #{schema.name} [#{schema.namespace}]\n"
        end

        # The schema on which the requests will be performed from
        def gql_schema
          schema = self.class.gql_schema
          schema = schema.safe_constantize if schema.is_a?(String)
          schema ||= application_default_schema
          return schema if schema.is_a?(Module) && schema < ::Rails::GraphQL::Schema

          raise ExecutionError, (+<<~MSG).squish
            Unable to find a valid schema for #{self.class.name},
            defined value: #{schema.inspect}.
          MSG
        end

        # Get the GraphQL query to execute
        def gql_query
          params[:query]
        end

        # Get the cache key of the query for persisted queries
        def gql_query_cache_key(key = nil, version = nil)
          return unless (key ||= params[:query_cache_key]).present?
          CacheKey.new(key, version || params[:query_cache_version])
        end

        # Get the GraphQL operation name
        def gql_operation_name
          params[:operationName] || params[:operation_name]
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
