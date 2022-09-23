# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Proxied Field
    #
    # Proxied fields are a soft way to copy a real field. The good part is that
    # if the field changes for any reason all its copies will change as well.
    #
    # The owner of a proxy field is different from the owner of the actual field
    # but that doesn't affect the field operations.
    #
    # Proxied field also supports aliases, which helps implementing independent
    # fields and then providing them as proxy to other objects.
    #
    # Proxies can be created from any kind of input
    #
    # ==== Options
    #
    # It accepts all the options of any other type of field plus the following
    #
    # * <tt>:owner</tt> - The main object that this field belongs to.
    # * <tt>:as</tt> - The actual name to be used on the field while assigning
    #   the proxy (defaults to nil).
    # * <tt>:alias</tt> - Same as the +:as+ key (defaults to nil).
    module Field::ProxiedField
      delegate_missing_to :field
      delegate :leaf_type?, :array?, :internal?, :valid_input?, :valid_output?,
        :to_json, :as_json, :deserialize, :valid?, :proxied_owner, to: :field

      Field.proxyable_methods %w[name gql_name method_name resolver description
        null? nullable? enabled?], klass: self

      def initialize(field, owner:, **xargs, &block)
        @field = field
        @owner = owner

        apply_changes(**xargs, &block)
      end

      # Once this module is added then the field becomes a proxy
      def proxy?
        true
      end

      # Allow chaging most of the general kind-independent initialize settings
      def apply_changes(**xargs, &block)
        if (deprecated = xargs[:deprecated])
          xargs[:directives] = Array.wrap(xargs[:directives])
          xargs[:directives] << Directive::DeprecatedDirective.new(
            reason: (deprecated.is_a?(String) ? deprecated : nil),
          )
        end

        # TODO: Replace by a proper method to build and set @directives
        @directives = GraphQL.directives_to_set(xargs[:directives], source: self) \
          if xargs.key?(:directives)

        @desc    = xargs[:desc]&.strip_heredoc&.chomp if xargs.key?(:desc)
        @enabled = xargs.fetch(:enabled, !xargs.fetch(:disabled, false)) \
          if xargs.key?(:enabled) || xargs.key?(:disabled)

        normalize_name(xargs.fetch(:alias, xargs[:as]))
        super
      end

      # Override this to include proxied owners
      def all_owners
        super + proxied_owner.all_owners
      end

      # Return the proxied field
      def proxied_field
        @field
      end

      # Just ensure that when the field is proxied to an interface it does not
      # allow disabling
      def disable!
        super unless non_interface_proxy!('disable')
      end

      # Just ensure that when the field is proxied to an interface it does not
      # allow enabling
      def enable!
        super unless non_interface_proxy!('enable')
      end

      # Prepend the proxy directives and then the source directives
      def all_directives
        inherited = field.all_directives
        return inherited unless defined?(@directives)
        inherited.present? ? inherited + super : super
      end

      # Check if the field has directives locally or in the proxied field
      def directives?
        super || field.directives?
      end

      # It is important to ensure that the proxied field is also valid
      def validate!(*)
        super if defined? super
        field.validate!
      end

      protected

        alias field proxied_field

        def normalize_name(value)
          super unless value.blank? || non_interface_proxy!('rename')
        end

        # Prohibits changes to proxy fields based on interfaces
        def non_interface_proxy!(action)
          raise ::ArgymentError, <<~MSG.squish if interface_proxy?
            Unable to #{action} the "#{gql_name}" field because it is
            associated to the #{field.owner.name} interface.
          MSG
        end

        # Checks if the proxy is based on an interface field
        def interface_proxy?
          field.owner.try(:interface?)
        end

        # Display the source of the proxy for inspection
        def inspect_source
          +"@source=#{field.owner.name}[:#{field.name}] [proxied]"
        end

        # This is trigerred when the field is proxied
        def proxied
          super if defined? super
        end
    end
  end
end
