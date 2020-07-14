# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Proxy Field
    #
    # Proxy fields are a soft way to copy a real field. The good part is that if
    # the field changes for any reason all its copies will change as well.
    #
    # The owner of a proxy field is different from the owner of the actual field
    # but that doesn't affect the field operations.
    #
    # Proxy field also supports aliases, which helps implementing independent
    # fields and then providing them as proxy to other objects
    class ProxyField < ActiveSupport::ProxyObject
      delegate_missing_to :@field

      attr_reader :owner

      def initialize(field, owner, as: nil)
        if as.present?
          @name = as.to_s.underscore.to_sym

          @gql_name = @name.to_s.camelize(:lower)
          @gql_name = "__#{@gql_name.camelize(:lower)}" if field.internal?
        end

        @field = field
        @owner = owner
      end

      def name
        @name || field.name
      end

      def gql_name
        @gql_name || field.gql_name
      end

      def inspect
        @field.inspect.gsub(
          /^#<GraphQL::Field @owner="[^"]+"/,
          "#<GraphQL::ProxyField @owner=\"#{owner.name}\"",
        )
      end
    end
  end
end
