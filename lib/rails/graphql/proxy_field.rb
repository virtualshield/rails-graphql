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

      delegate :type, :array?, :nullable?, :internal?, to: :field

      redefine_singleton_method(:output_type?) { true }
      redefine_singleton_method(:proxy?) { true }

      def initialize(field, owner, **xargs, &block)
        @field = field
        @owner = owner

        apply_changes(**xargs, &block)

        directives.freeze
        arguments.freeze
      end

      # Allow chaging the name of a proxy field
      def apply_changes(**xargs, &block)
        @method_name = xargs[:method_name] unless xargs.key?(:method_name)
        normalize_name(xargs.fetch(:alias, xargs[:as]))

        super
      end

      # Generate a set of methods that can be set or passed to the proxied field
      %i[name gql_name method_name null? enabled?].each do |name|
        ivar = name.to_s.delete_suffix('?')
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{name}
            defined?(@#{ivar}) ? @#{ivar} : field.#{name}
          end
        RUBY
      end

      # Checks both self and proxied resolver hooks
      def listeners
        list = resolver_hooks.keys
        list += field.listeners
        list << :resolver if dynamic_resolver?
        list
      end

      def disable! # :nodoc:
        super unless non_interface_proxy!('disable')
      end

      def enable! # :nodoc:
        super unless non_interface_proxy!('enable')
      end

      def all_directives # :nodoc:
        field.directives + super
      end

      def all_arguments # :nodoc:
        field.all_arguments.merge(super)
      end

      def has_argument?(name) # :nodoc:
        field.has_argument?(name) || super
      end

      def dynamic_resolver? # :nodoc:
        super || field.dynamic_resolver?
      end

      def inspect(extra = '') # :nodoc:
        <<~INSPECT.squish + '>'
          #<GraphQL::ProxyField
          @owner="#{owner.name}"
          @source="#{field.owner.name}[:#{field.name}]"
          #{gql_name}#{inspect_arguments}:#{extra}#{inspect_directives}
        INSPECT
      end

      protected
        attr_reader :field

        def normalize_name(value) # :nodoc:
          super unless value.blank? || non_interface_proxy!('rename')
        end

        def run_resolver(context) # :nodoc:
          self_dynamic_resolver? ? super : field.run(:resolver, context)
        end

        def run_hooks(hook, context) # :nodoc:
          super
          field.run(hook, context)
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
