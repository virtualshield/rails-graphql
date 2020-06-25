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
    class ProxyField < ActiveSupport::ProxyObject
      delegate_missing_to :@field

      attr_reader :owner

      def initialize(field, owner)
        @field = field
        @owner = owner
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
