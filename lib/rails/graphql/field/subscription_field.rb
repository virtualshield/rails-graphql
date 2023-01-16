# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Subscription Field
    #
    # TODO: Finish and add description
    class Field::SubscriptionField < Field::OutputField
      redefine_singleton_method(:subscription?) { true }
      event_types(:subscribed, append: true)

      attr_reader :prepare_context

      module Proxied # :nodoc: all
        def full_scope
          field.full_scope + super
        end

        def prepare_context
          super || field.prepare_context
        end
      end

      # Change the schema type of the field
      def schema_type
        :subscription
      end

      # A kind of alias to the subscribe event available
      def subscribed(*args, **xargs, &block)
        on(:subscribed, *args, **xargs, &block)
        self
      end

      # Set the parts of the scope of the subscription
      def scope(*parts)
        (defined?(@scope) ? (@scope += parts) : (@scope = parts)).freeze
      end

      # Get the full scope of the field
      def full_scope
        return EMPTY_ARRAY unless defined?(@scope)
      end

      # Checks if the scope is correctly defined
      def validate!(*)
        super if defined? super
        return unless defined?(@scope)

        invalid = @scope.reject { |item| item.is_a?(Symbol) || item.is_a?(Proc) }
        raise ArgumentError, (+<<~MSG).squish if invalid.any?
          The "#{type_klass.gql_name}" has invalid values set for its scope: #{invalid.inspect}.
        MSG
      end

      # A shortcut for trigger when everything is related to the provided object
      # TODO: Maybe add support for object as an array of things
      # TODO: Add support for +data_for+. The only problem right now is that
      # providers run asynchronously, so passing data is a bit more complicated
      # and maybe dangerous (size speaking)
      def trigger_for(object, **xargs)
        match_valid_object!(object)
        xargs[:args] ||= extract_args_from(object)
        trigger(**xargs)
      end

      # A shortcut for unsubscribe when everything is related to the provided
      # object
      # TODO: Maybe add support for object as an array of things
      def unsubscribe_from(object, **xargs)
        match_valid_object!(object)
        xargs[:args] ||= extract_args_from(object)
        unsubscribe(**xargs)
      end

      # Trigger an update to the subscription
      def trigger(args: nil, scope: nil)
        provider = owner.subscription_provider
        provider.search_and_update(field: self, args: args, scope: scope)
      end

      # Force matching subscriptions to be removed
      def unsubscribe(args: nil, scope: nil)
        provider = owner.subscription_provider
        provider.search_and_remove(field: self, args: args, scope: scope)
      end

      protected

        # Match any argument with properties from the given +object+ so it
        # produces all the possibilities of an update
        def extract_args_from(object)
          return unless arguments?

          # Prepare all the possibilities
          keys = []
          hash_like = object.respond_to?(:[])
          possibilities = all_arguments.each_value.with_object([]) do |arg, list|
            keys << arg.name
            list << []

            value =
              if object.respond_to?(arg.name)
                object.public_send(arg.name)
              elsif hash_like && (object.key?(arg.name) || object.key?(arg.name.to_s))
                object[arg.name] || arg.name[arg.name.to_s]
              end

            list.last << value unless value.nil?
            list.last << nil if arg.null?
          end

          # Now turn them into actual possible args
          possibilities.reduce(:product).flatten.each_slice(keys.size).map do |items|
            keys.zip(items).to_h
          end
        end

        # Check if the provided +object+ is a match for the type that this field
        # is associated with
        def match_valid_object!(object)
          raise ::ArgumentError, (+<<~MSG).squish unless type_klass&.object?
            Cannot trigger with an object when the field is not associated to
            an object-like result.
          MSG

          assignable = !object.is_a?(Module) && type_klass.valid_member?(object)
          raise ::ArgumentError, (+<<~MSG).squish unless assignable
            The provided object "#{object.inspect}" is not a valid member of
            #{type_klass.inspect} for the :#{name} field.
          MSG
        end

        def proxied
          super if defined? super
          extend Field::SubscriptionField::Proxied
        end
    end
  end
end
