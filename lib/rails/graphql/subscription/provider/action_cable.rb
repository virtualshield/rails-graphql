# frozen_string_literal: true

require 'action_cable'

module Rails
  module GraphQL
    module Subscription
      module Provider
        # = GraphQL Action Cable Subscription Provider
        #
        # The subscription provider associated with Rails Action Cable, that
        # delivers subscription notifications through an Action Cable Channel
        class ActionCable < Base
          INTERNAL_CHANNEL = 'rails-graphql:events'

          attr_reader :cable, :prefix

          def initialize(*args, **options)
            @cable = options.fetch(:cable, ::ActionCable)
            @prefix = options.fetch(:prefix, 'graphql')

            @event_callback = ->(message) do
              method_name, args, xargs = Marshal.load(message)
              @mutex.synchronize { send(method_name, *args, **xargs) }
            end

            super
          end

          def shutdown
            @pubsub = nil
          end

          def accepts?(operation)
            operation.request.origin.is_a?(::ActionCable::Channel::Base)
          end

          def add(*subscriptions)
            with_pubsub do
              subscriptions.each do |item|
                log(:added, item)
                store.add(item)
                stream_from(item)
              end
            end
          end

          def async_remove(item)
            return unless instance?(item) || !(item = store.fetch(item)).nil?
            cable.server.broadcast(stream_name(item), unsubscribed_payload)
            store.remove(item)

            log(:removed, item)
          end

          def async_update(item, data = nil)
            return unless instance?(item) || !(item = store.fetch(item)).nil?
            removing = false

            log(:updated, item) do
              data = execute(item) if data.nil?
              item.updated!

              unless (removing = unsubscribing?(data))
                data = { 'result' => data, 'more' => true }
                cable.server.broadcast(stream_name(item), data)
              end
            end

            async_remove(item) if removing
          end

          def stream_name(item)
            "#{prefix}:#{instance?(item) ? item.sid : item}"
          end

          protected

            def stream_from(item)
              item.origin.stream_from(stream_name(item))
            end

            def execute(subscription, **xargs)
              super(subscription, origin: subscription.origin, **xargs, as: :hash)
            end

            def async_exec(method_name, *args, **xargs)
              payload = [method_name, args, store.serialize(**xargs)]
              with_pubsub { @pubsub.broadcast(INTERNAL_CHANNEL, Marshal.dump(payload)) }
              nil
            end

            def with_pubsub(&callback)
              success = -> { cable.server.event_loop.post(&callback) }
              return success.call if defined?(@pubsub) && !@pubsub.nil?

              cable.server.pubsub.subscribe(INTERNAL_CHANNEL, @event_callback, success)
              @pubsub = cable.server.pubsub
            end

            def validate!
              super

              raise ValidationError, (+<<~MSG).squish if @prefix.blank?
                Unable to setup #{self.class.name} because a proper prefix was not provided.
              MSG
            end
        end
      end
    end
  end
end
