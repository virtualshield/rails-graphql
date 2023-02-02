# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Subscription Field
    #
    # This is an extension of a normal output field, which will sign
    # the request for updates of the field when the scope and arguments
    # are the same.
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

      # Intercept the initializer to maybe set the +scope+
      def initialize(*args, scope: nil, **xargs, &block)
        @scope = Array.wrap(scope).freeze unless scope.nil?
        super(*args, **xargs, &block)
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
        self
      end

      # Get the full scope of the field
      def full_scope
        defined?(@scope) ? @scope : EMPTY_ARRAY
      end

      # A shortcut for trigger when everything is related to the provided object
      def trigger_for(object, and_prepare: true, **xargs)
        xargs[:args] ||= extract_args_from(object)

        if and_prepare
          xargs[:data_for] ||= {}
          xargs[:data_for][+"subscription.#{gql_name}"] = object
        end

        trigger(**xargs)
      end

      # A shortcut for unsubscribe when everything is related to the provided
      # object
      def unsubscribe_from(object, **xargs)
        xargs[:args] ||= extract_args_from(object)
        unsubscribe(**xargs)
      end

      # Trigger an update to the subscription
      def trigger(**xargs)
        provider = owner.subscription_provider
        provider.search_and_update(field: self, **xargs)
      end

      # Force matching subscriptions to be removed
      def unsubscribe(**xargs)
        provider = owner.subscription_provider
        provider.search_and_remove(field: self, **xargs)
      end

      protected

        # Match any argument with properties from the given +object+ so it
        # produces all the possibilities of an update
        def extract_args_from(object, iterate = true)
          return unless arguments?

          # If can iterate and the provided object is an enumerable, then
          # call itself with each item
          if iterate && object.is_a?(Enumerable)
            return object.each_with_object([]) do |item, result|
              result.concat(extract_args_from(item, false))
            end
          end

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

        def proxied
          super if defined? super
          extend Field::SubscriptionField::Proxied
        end
    end
  end
end
