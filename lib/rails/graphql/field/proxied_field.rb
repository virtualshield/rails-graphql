# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Proxied Field
    #
    # A little shared helper that allows a correct "proxylization" of a field
    # that behaves as a proxy
    module Field::ProxiedField
      delegate :input_type?, :output_type?, :leaf_type?, :from_ar?, :from_ar,
        :array?, :nullable?, :internal?, :valid_input?, :valid_output?,
        :to_json, :to_hash, :deserialize, :valid?, to: :field

      delegate_missing_to :field

      def self.included(other)
        other.extend(ClassMethods)
      end

      module ClassMethods
        # Change the value to true
        def proxy?
          true
        end

        protected

          # A helper to define methods that allows overrides by the proxy
          def overrideable_methods(*list, allow_nil: false)
            list.flatten.each do |method_name|
              ivar = '@' + method_name.delete_suffix('?')
              accessor = 'field' + (allow_nil ? '&.' : '.') + method_name
              class_eval <<~RUBY, __FILE__, __LINE__ + 1
                def #{method_name}
                  defined?(#{ivar}) ? #{ivar} : #{accessor}
                end
              RUBY
            end
          end
      end

      # Allow chaging most of the general kind-independent initialize settings
      def apply_changes(**xargs, &block)
        if (deprecated = xargs[:deprecated])
          xargs[:directives] = Array.wrap(xargs[:directives])
          xargs[:directives] << Directive::DeprecatedDirective.new(
            reason: (deprecated.is_a?(String) ? deprecated : nil),
          )
        end

        @directives = GraphQL.directives_to_set(xargs[:directives], source: self) \
          if xargs.key?(:directives)

        @method_name = xargs[:method_name] if xargs.key?(:method_name)

        @desc    = xargs[:desc]&.strip_heredoc&.chomp if xargs.key?(:desc)
        @enabled = xargs.fetch(:enabled, !xargs.fetch(:disabled, false)) \
          if xargs.key?(:enabled) || xargs.key?(:disabled)

        normalize_name(xargs.fetch(:alias, xargs[:as]))
        super
      end

      # Return the original owner from +field+
      def proxied_owner
        field.owner
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
        field.all_directives + ((super if defined? super) || Set.new)
      end

      def all_listeners # :nodoc:
        field.all_listeners + super
      end

      def all_events # :nodoc:
        Helpers::Helpers::AttributeDelegator.new do
          Helpers::InheritedCollection.merge_hash_array(field.all_events, super)
        end
      end

      def has_argument?(name) # :nodoc:
        super || field.has_argument?(name)
      end

      def dynamic_resolver? # :nodoc:
        super || field.dynamic_resolver?
      end

      protected
        attr_reader :field

        def normalize_name(value) # :nodoc:
          super unless value.blank? || non_interface_proxy!('rename')
        end

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
