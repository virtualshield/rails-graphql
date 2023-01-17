# frozen_string_literal: true

module Rails
  module GraphQL
    module Subscription
      module Provider
        # = GraphQL Base Subscription Provider
        #
        # The base class for all the other subscription providers, which defines
        # the necessary interfaces to install and stream the subscription to
        # their right places
        #
        # As a way to properly support ActiveRecord objects as part of the scope
        # in a way that does not require queries and instance, a hash scope,
        # where we have the class as the key and one or more ids as values,
        # must be supported. In general, a implementation using +.hash+ is
        # recommended because +User.find(1).hash == User.class.hash ^ 1.hash+
        class Base
          # An abstract type won't appear in the introspection and will not be
          # instantiated by requests
          class_attribute :abstract, instance_accessor: false, default: false

          delegate :fetch, :search, :find_each, to: :store

          class << self

            # Make sure that abstract classes cannot be instantiated
            def new(*, **)
              return super unless self.abstract

              raise StandardError, (+<<~MSG).squish
                #{name} is abstract and cannot be used as a subscription provider.
              MSG
            end

            # Make sure to run the provided +methods+ in async mode. Use the
            # lock to identify if it's already running in async or not
            def async_exec(*method_names)
              method_names.each do |method_name|
                async_method_name = :"async_#{method_name}"

                class_eval do
                  return warn((+<<~MSG).squish) if method_defined?(async_method_name)
                    Already async #{method_name}
                  MSG

                  alias_method async_method_name, method_name

                  define_method(method_name) do |*args, **xargs|
                    if @mutex.owned?
                      send(async_method_name, *args, **xargs)
                    else
                      async_exec(async_method_name, *args, **xargs)
                    end
                  end
                end
              end
            end

          end

          def initialize(**options)
            @store = options.fetch(:store, Store::Memory.new)
            @logger = options.fetch(:logger, GraphQL.logger)
            @mutex = Mutex.new

            validate!
          end

          # Use this method to remove variables that needs to be restarted when
          # the provider is doing a refresh. Remember to keep the data in the
          # store so that it can still recover and keep posting updates
          def shutdown
          end

          # Before even generating the item, check if the operation can be
          # subscribed
          def accepts?(operation)
            raise NotImplementedError, +"#{self.class.name} does not implement accepts?"
          end

          # Add one or more subscriptions to the provider
          def add(*subscriptions)
            raise NotImplementedError, +"#{self.class.name} does not implement add"
          end

          # Remove one subscription from the provider, assuming that they will
          # be properly notified about the removal. For a group operation, use
          # +search_and_remove+
          async_exec def remove(item)
            raise NotImplementedError, +"#{self.class.name} does not implement remove"
          end

          # Update one single subscription, for broadcasting, use +update_all+
          # or +search_and_update+. You can provide the +data+ that will be sent
          # to upstream, skipping it from being collected from a request
          async_exec def update(item, data = nil)
            raise NotImplementedError, +"#{self.class.name} does not implement update"
          end

          # A simple shortcut for calling remove on each individual sid
          async_exec def remove_all(*items)
            items.each(&method(:remove))
          end

          # A simple shortcut for calling update on each individual sid
          async_exec def update_all(*sids)
            return if sids.blank?

            enum = GraphQL.enumerate(store.fetch(*sids))
            enum.group_by(&:operation_id).each_value do |subscriptions|
              data = execute(subscriptions.first, broadcasting: true) \
                unless subscriptions.one? || first.broadcastable?

              subscriptions.each { |item| update(item, data) }
            end
          end

          # A shortcut for finding the subscriptions and then remove them
          async_exec def search_and_remove(**options)
            find_each(**options, &method(:remove))
          end

          # A shortcut for finding the subscriptions and then updating them
          async_exec def search_and_update(**options)
            update_all(*find_each(**options))
          end

          # Get the payload that should be used when unsubscribing
          def unsubscribed_payload
            Request::Component::Operation::Subscription::UNSUBSCRIBED_PAYLOAD
          end

          # Check if the given +value+ indicates that it is unsubscribing
          def unsubscribing?(value)
            value == Request::Component::Operation::Subscription::UNSUBSCRIBED_RESULT
          end

          protected
            attr_reader :store, :logger

            # Make sure to set sub provider as not abstract
            def inherited(other)
              other.abstract = false
              super
            end

            # Check if the given +object+ is a subscription instance
            def instance?(object)
              object.is_a?(Request::Subscription)
            end

            # Logo a given +event+ for the given +item+
            def log(event, item = nil, &block)
              data = { item: item, type: event, provider: self }
              ActiveSupport::Notifications.instrument('subscription.graphql', **data, &block)
            end

            # Create a new request and execute, but using all the information
            # stored in the provided +subscription+
            def execute(subscription, broadcasting: false, **xargs)
              catch(:skip_subscription_update) do
                context = subscription.context.dup
                context[:broadcasting] = true if broadcasting
                xargs.reverse_merge(context: context, as: :string)

                namespace = subscription.schema
                Request.execute(nil, **xargs, namespace: namespace, hash: subscription.sid)
              end
            end

            # Make sure to rewrite this method so that you can properly execute
            # methods asynchronously. Remember to
            def async_exec(method_name, *args, **xargs)
              @mutex.synchronize { send(method_name, *args, **xargs) }
            end

            # Make sure that the settings provided are enough to operate
            def validate!
              valid = defined?(@store) && @store.is_a?(Subscription::Store::Base)
              raise ValidationError, (+<<~MSG).squish unless valid
                Unable to setup #{self.class.name} because a proper store was not
                defined, "#{@store.inspect}" was provided.
              MSG
            end

        end
      end
    end
  end
end
