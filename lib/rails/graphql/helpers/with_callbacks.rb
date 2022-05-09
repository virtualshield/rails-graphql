# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Callbacks is an extension of the events which works with the
      # {Callback}[rdoc-ref:Rails::GraphQL::Callback] class, then having extra
      # powers when actually executing the event against procs or owner-based
      # symbolic methods
      module WithCallbacks
        DEFAULT_EVENT_TYPES = %i[query mutation subscription request attach
          authorize organized prepared finalize].freeze

        def self.extended(other)
          other.extend(WithCallbacks::Setup)
        end

        def self.included(other)
          other.extend(WithCallbacks::Setup)
          other.delegate(:event_filters, to: :class)
        end

        # Add the ability to set up filters before the actual execution of the
        # callback
        module Setup
          # Use the default list of event types when it's not set
          def event_types(*, **)
            (super if defined? super).presence || DEFAULT_EVENT_TYPES
          end

          # Return the list of event filters hooks
          def event_filters
            return @event_filters if defined? @event_filters
            superclass.try(:event_filters) || {}
          end

          protected

            # Attach a new key based event filter
            def event_filter(key, &block)
              @event_filters ||= superclass.try(:event_filters)&.dup || {}
              @event_filters[key.to_sym] = block
            end
        end

        # Enhance the event by evolving the block to a
        # {Callback}[rdoc-ref:Rails::GraphQL::Callback] object.
        def on(event_name, *args, unshift: false, **xargs, &block)
          block = Callback.new(self, event_name, *args, **xargs, &block)
          super(event_name, block, unshift: unshift)
        end
      end
    end
  end
end
