# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Controller
    #
    # The controller helper methods that allow GraphQL to be performed on a
    # Rails Controller class
    module Controller
      extend ActiveSupport::Concern

      REQUEST_XARGS = %i[operation_name variables context schema query_cache_key].freeze
      DESCRIBE_HEADER = <<~TXT.freeze
        """
        Use the following HTTP params to modify this result:
          without_descriptions => Hide all descriptions
          without_spec => Hide all default spec types
        """
      TXT

      included do
        # Each controller is assigned to a GraphQL schema on which the requests
        # will be performed from. It can be a string or the class
        class_attribute :gql_schema, instance_accessor: false

        # Add the internal views directory
        prepend_view_path("#{__dir__}/app/views")
      end

      # POST /execute
      def execute
        gql_request_response(gql_query)
      end

      # GET /describe
      def describe(schema = gql_schema)
        render plain: [
          gql_schema_header(schema),
          gql_describe_schema(schema),
          gql_schema_footer,
        ].join
      end

      # GET /graphiql
      def graphiql
        render '/graphiql', layout: false, locals: { settings: graphiql_settings }
      end

      protected

        # Identifies if the request should be threated as a compiled request
        def gql_compiled_request?(*)
          false
        end

        # Render a response as a GraphQL request
        def gql_request_response(*args, **xargs)
          render json: gql_request(*args, **xargs)
        end

        # Execute a GraphQL request
        def gql_request(document, **xargs)
          request_xargs = REQUEST_XARGS.each_with_object({}) do |setting, result|
            result[setting] ||= (xargs[setting] || send(:"gql_#{setting}"))
          end

          request_xargs[:hash] ||= gql_query_cache_key
          request_xargs[:origin] ||= self
          request_xargs[:compiled] ||= gql_compiled_request?(document)

          request_xargs = request_xargs.except(*%i[query_cache_key query_cache_version])
          ::Rails::GraphQL::Request.execute(document, **request_xargs)
        end

        # The schema on which the requests will be performed from
        def gql_schema
          return @gql_schema if defined?(@gql_schema)

          schema = self.class.gql_schema
          schema = schema.constantize if schema.is_a?(String)
          schema ||= gql_application_default_schema

          return @gql_schema = schema if schema.is_a?(Module) &&
            schema < ::Rails::GraphQL::Schema

          raise ExecutionError, (+<<~MSG).squish
            Unable to find a valid schema for #{self.class.name},
            defined value: #{schema.inspect}.
          MSG
        end

        # Get the GraphQL query to execute
        def gql_document
          params[:query]
        end

        alias gql_query gql_document

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

        # Return the settings for the GraphiQL view
        def graphiql_settings(mode = nil)
          if mode == :cable
            { mode: :cable, url: '/cable', channel: 'GraphQL::BaseChannel' }
          else
            { mode: :fetch, url: '/graphql' }
          end
        end

        # Shows a text representation of the schema
        def gql_describe_schema(schema)
          schema.to_gql(
            with_descriptions: !params.key?(:without_descriptions),
            with_spec: !params.key?(:without_spec),
            with_hidden: params.key?(:with_hidden),
          )
        end

        # Print a header of the current schema for the description process
        # TODO: Maybe add a way to detect from which file the schema is being loaded
        def gql_schema_header(schema)
          ns = +" [#{schema.namespace}]" if schema.namespace != :base
          +"#{DESCRIBE_HEADER}# Schema #{schema.name}#{ns}\n"
        end

        # Show the footer of the describe page
        def gql_schema_footer
          $/ + $/ + '# Version: ' + gql_version + $/ +
            '# Rails GraphQL ' + ::Rails::GraphQL::VERSION::STRING +
            ' (Spec ' + ::GQLParser::VERSION + ')'
        end

        # Get the version of the running instance of GraphQL
        def gql_version
          ::Rails::GraphQL.type_map.version
        end

      private

        # Find the default application schema
        def gql_application_default_schema
          app_class = Rails.application.class.name.chomp('::Application')
          klass = "::GraphQL::#{app_class}Schema".safe_constantize
          self.class.gql_schema = klass
        end
    end
  end
end
