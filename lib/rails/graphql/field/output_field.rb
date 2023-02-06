# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Output Field
    #
    # Most of the fields in a GraphQL operation are output fields or similar or
    # proxies of it. They can express both leaf and branch data. They can also
    # be the entry point of a GraphQL request.
    #
    # ==== Options
    #
    # * <tt>:method_name</tt> - The name of the method used to fetch the field data
    #   (defaults to nil).
    # * <tt>:deprecated</tt> - A shortcut to adding a deprecated directive to the field
    #   (defaults to nil).
    class Field::OutputField < Field
      # Do not change this order because it can affect how events work. Callback
      # must always come after events
      include Helpers::WithArguments
      include Helpers::WithEvents
      include Helpers::WithCallbacks

      include Helpers::WithGlobalID
      include Helpers::WithValidator

      include Field::AuthorizedField
      include Field::ResolvedField
      include Field::TypedField

      module Proxied # :nodoc: all
        Field.proxyable_methods %w[broadcastable?], klass: self

        def all_arguments
          inherited = field.all_arguments
          return inherited unless defined?(@arguments)
          inherited.blank? ? super : inherited.merge(super)
        end

        def has_argument?(name)
          super || field.has_argument?(name)
        end

        def arguments?
          super || field.arguments?
        end

        # TODO: Break events into directive/type/local
        # because type events should only be added
        # from the proxy
        def all_events
          if (inherited = super).nil?
            field.all_events
          elsif (proxied = field.all_events).nil?
            inherited
          else
            # The order is reversed because events from
            # the proxy must come first
            Helpers.merge_hash_array(proxied, inherited)
          end
        end

        def events?
          super || field.events?
        end

        def all_listeners
          if (inherited = super).nil?
            field.all_listeners
          elsif (proxied = field.all_listeners).nil?
            inherited
          else
            proxied + inherited
          end
        end

        def listeners?
          super || field.listeners?
        end
      end

      redefine_singleton_method(:output_type?) { true }
      self.directive_location = :field_definition

      def initialize(*args, method_name: nil, deprecated: false, **xargs, &block)
        @method_name = method_name.to_s.underscore.to_sym unless method_name.nil?
        @broadcastable = xargs.delete(:broadcastable) if xargs.key?(:broadcastable)

        if deprecated.present?
          xargs[:directives] = ::Array.wrap(xargs[:directives])
          xargs[:directives] << Directive::DeprecatedDirective.new(
            reason: (deprecated.is_a?(String) ? deprecated : nil),
          )
        end

        super(*args, **xargs, &block)
      end

      # Accept changes to the method name through the +apply_changes+
      def apply_changes(**xargs, &block)
        @method_name = xargs.delete(:method_name) if xargs.key?(:method_name)
        super
      end

      # By default, output fields that belongs to a schema is a query field
      def schema_type
        :query
      end

      # Check if the arguments are also equivalent
      def =~(other)
        super && match_arguments?(other)
      end

      # Checks if a given raw value is valid for this field
      def valid_output?(value, deep: true)
        return false unless super
        return null? if value.nil?
        return valid_output_array?(value, deep) if array?

        return true unless leaf_type? || deep
        type_klass.valid_output?(value)
      end

      # Trigger the exception based value validator
      def validate_output!(value, **xargs)
        super(value, :field, **xargs)
      rescue ValidationError => error
        raise InvalidValueError, error.message
      end

      # Checks if the default value of the field is valid
      def validate!(*)
        super if defined? super

        raise ArgumentError, (+<<~MSG).squish unless type_klass.output_type?
          The "#{type_klass.gql_name}" is not a valid output type.
        MSG
      end

      def all_events
        if !defined?(@events) || !(local = @events).present?
          super
        elsif (inherited = super).nil?
          local
        else
          Helpers.merge_hash_array(inherited, local)
        end
      end

      def events?
        super || defined?(@events) && @events.present?
      end

      def all_listeners
        if !defined?(@listeners) || !(local = @listeners).present?
          super
        elsif (inherited = super).nil?
          local
        else
          inherited + local
        end
      end

      def listeners?
        super || defined?(@listeners) && @listeners.present?
      end

      def broadcastable?
        defined?(@broadcastable) && @broadcastable
      end

      def entry_point?
        owner.is_a?(Helpers::WithSchemaFields)
      end

      protected

        # Check if the given +value+ is a valid array as output
        def valid_output_array?(value, deep)
          return false unless value.is_a?(Enumerable)

          value.all? do |val|
            (val.nil? && nullable?) || (leaf_type? || !deep) ||
              type_klass.valid_output?(val)
          end
        end

        # Properly display the owner section when the field is owned by a Schema
        def inspect_owner
          entry_point? ? +"#{owner.name}[:#{schema_type}]" : super
        end

        def proxied
          super if defined? super
          extend Field::OutputField::Proxied
        end
    end
  end
end
