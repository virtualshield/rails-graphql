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
    class ProxyField
      include Helpers::WithDirectives

      include Field::Core
      include Field::ResolvedField
      include Field::TypedOutputField

      alias self_dynamic_resolver? dynamic_resolver?
      alias all_proxy_directives all_directives

      delegate :type, :array?, :nullable?, :internal?, to: :field

      redefine_singleton_method(:output_type?) { true }
      redefine_singleton_method(:proxy?) { true }

      def initialize(field, owner, **xargs, &block)
        @field = field
        @owner = owner

        apply_changes(**xargs, &block)
      end

      # Allow chaging the name of a proxy field
      def apply_changes(**xargs, &block)
        if xargs.key?(:method_name)
          @method_name = xargs[:method_name]
        end

        normalize_name(xargs.fetch(:alias, xargs[:as]))

        super
      end

      # Return the original owner from +field+
      def proxied_owner
        field.owner
      end

      # Generate a set of methods that can be set or passed to the proxied field
      %w[name gql_name method_name resolver null? enabled?].each do |method_name|
        ivar = method_name.delete_suffix('?')
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{method_name}
            defined?(@#{ivar}) ? @#{ivar} : field.#{method_name}
          end
        RUBY
      end

      def disable! # :nodoc:
        super unless non_interface_proxy!('disable')
      end

      def enable! # :nodoc:
        super unless non_interface_proxy!('enable')
      end

      def all_arguments # :nodoc:
        field.arguments.merge(super)
      end

      def all_directives # :nodoc:
        field.all_directives + all_proxy_directives
      end

      def all_listeners # :nodoc:
        field.all_listeners + super
      end

      def all_events # :nodoc:
        Helpers::InheritedCollection::LazyValue.new do
          Helpers::InheritedCollection.merge_hash_array!(field.all_events, super)
        end
      end

      def has_argument?(name) # :nodoc:
        super || field.has_argument?(name)
      end

      def dynamic_resolver? # :nodoc:
        super || field.dynamic_resolver?
      end

      def inspect # :nodoc:
        <<~INSPECT.squish + '>'
          #<GraphQL::ProxyField
          @owner="#{owner.name}"
          @source="#{field.owner.name}[:#{field.name}]"
          #{gql_name}#{inspect_arguments}:#{inspect_type}#{inspect_directives}
        INSPECT
      end

      protected
        attr_reader :field

        def normalize_name(value) # :nodoc:
          super unless value.blank? || non_interface_proxy!('rename')
        end

      private

        # Prohibits changes to proxy fields based on interfaces
        def non_interface_proxy!(action)
          raise ::ArgymentError, <<~MSG.squish if interface_proxy?
            Unable to #{action} the "#{gql_name}" field because it is
            associated to the #{field.owner.gql_name} interface.
          MSG
        end

        # Checks if the proxy is based on an interface field
        def interface_proxy?
          field.owner.try(:interface?)
        end
    end
  end
end
