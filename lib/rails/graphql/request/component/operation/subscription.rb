# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      class Component
        # = GraphQL Request Component Subscription Operation
        #
        # Handles a subscription operation inside a request.
        class Operation::Subscription < Operation
          UNSUBSCRIBED_PAYLOAD = { 'more' => false }.freeze
          UNSUBSCRIBED_RESULT = Object.new

          redefine_singleton_method(:subscription?) { true }

          def initialize(*)
            @initial = true

            super
          end

          # Fetch the subscription only when necessary
          def subscription
            return unless defined?(@subscription)
            return @subscription if @subscription.is_a?(Request::Subscription)
            @subscription = schema.subscription_provider.fetch(@subscription)
          end

          # Check if the operation is running in its first iteration, which will
          # produce a subscription to the field
          def subscribing?
            @initial
          end

          # Check if the current operation is running under broadcasting mode
          def broadcasting?
            request.context.broadcasting == true
          end

          # Check if the operation can be broadcasted
          def broadcastable?
            return @broadcastable if defined?(@broadcastable)
            @broadcastable = selection.each_value.all?(&:broadcastable?)
          end

          # Either throw back an empty result or skip the operation
          def no_update!
            subscribing? ? skip! : throw(:skip_subscription_update, EMPTY_HASH)
          end

          # If unsubscribe is called during an update, skip and return a proper
          # result
          def unsubscribe!
            if subscribing?
              schema.remove_subscriptions(subscription.sid) if subscription.present?
            else
              throw(:skip_subscription_update, UNSUBSCRIBED_RESULT)
            end
          end

          # Build the cache object
          def cache_dump(initial = true)
            hash = super()
            hash[:initial] = initial
            hash[:broadcastable] = broadcastable?

            unless initial
              hash[:sid] = @subscription&.sid
              hash[:variables] = @variables
            end

            hash
          end

          # Organize from cache data
          def cache_load(data)
            @initial = data[:initial]
            @broadcastable = data[:broadcastable]

            unless subscribing?
              @variables = data[:variables]
              @subscription = data[:sid]
            end

            super
          end

          protected

            # Rewrite this method so that the subscription can be generated in
            # the right place
            def resolve_then(&block)
              super do
                save_subscription
                trigger_event(:subscribed, subscription: subscription)
                block.call if block.present?
              end
            end

            # Save the subscription using the schema subscription provider
            def save_subscription
              return unless subscribing? && !(invalid? ||skipped?)
              check_invalid_subscription!

              @subscription = Request::Subscription.new(request, self)
              request.write_cache_request(subscription.sid, build_subscription_cache)
              schema.add_subscriptions(subscription)

              request.subscriptions[subscription.sid] = subscription
            rescue => e
              if subscription.present?
                schema.delete_from_cache(subscription.sid)
                schema.remove_subscriptions(subscription.sid)
              end

              raise SubscriptionError, (+<<~MSG).squish
                Unable to proper setup a subscription on #{display_name}: #{e.message}
              MSG
            end

            # A subscription is invalid if more than one field was requested or
            # if the only thing in the selection is a spread
            def check_invalid_subscription!
              raise ValidationError, (+<<~MSG).squish if @selection.size != 1
                It has #{@selection.size} and must have 1 single field on it.
              MSG

              element = @selection.each_value.first
              raise ValidationError, (+<<~MSG).squish unless element.kind == :field
                The only element inside of it must be a field, #{element.kind} found.
              MSG

              raise ValidationError, (+<<~MSG).squish if element.is_a?(Component::Typename)
                Unable to subscribe to a __typeName field.
              MSG

              raise ValidationError, (+<<~MSG).squish if element.unresolvable?
                Field is unresolvable.
              MSG

              raise ValidationError, (+<<~MSG).squish unless schema.accepts_subscription?(self)
                Operation unaccepted.
              MSG
            end

            # Very similar to the +cache_dump+ from the request, however this
            # will chop the parts exclusively for the subscription
            def build_subscription_cache
              # Prepare each used fragment to be set on cache and on the document
              frag_nodes = []
              fragments = used_fragments.empty? ? nil : begin
                request.fragments.slice(*used_fragments).transform_values do |frag|
                  frag_nodes << frag.instance_variable_get(:@node)
                  frag.try(:cache_dump)
                end.compact
              end

              # Return the cache result
              {
                strategy: { class: request.strategy.class },
                operation_name: request.operation_name,
                type_map_version: request.schema.version,
                document: [[@node], frag_nodes.presence],
                errors: request.errors.cache_dump,
                operations: { name => cache_dump(false) },
                fragments: fragments,
              }
            end

        end
      end
    end
  end
end
