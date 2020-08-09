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
    #
    # ==== Options
    #
    # * <tt>:as</tt> - The actual name to be used on the field while assigning
    #   the proxy (defaults to nil).
    # * <tt>:alias</tt> - Same as the +:as+ key (defaults to nil).
    # * <tt>:method_name</tt> - Provides a diferent +method_name+ from where to
    #   extract the data (defaults to nil).
    class Field::ProxyField
      include Helpers::WithDirectives
      include Helpers::WithArguments

      include Field::Core
      include Field::ProxiedField
      include Field::ResolvedField

      overrideable_methods %w[name gql_name method_name resolver description null? enabled?]

      def initialize(field, owner: , **xargs, &block)
        @field = field
        @owner = owner

        apply_changes(**xargs, &block)
      end

      def inspect # :nodoc:
        extra = field.send(:inspect_type) rescue nil
        args = send(:inspect_arguments) rescue nil

        <<~INSPECT.squish + '>'
          #<GraphQL::Field::ProxyField
          @owner=#{owner.name}
          @source=#{proxied_owner.name}[:#{field.name}]
          #{'[disabled]' if disabled?}
          #{gql_name}#{args}#{extra}#{inspect_directives}
        INSPECT
      end
    end
  end
end
