# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold events, either from a
      # singleton point-of-view, or for instances
      module WithEvents
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.extend(WithEvents::FixedTypes)

          other.inherited_collection(:events, type: :array_hash)
          other.inherited_collection(:listeners)
        end

        def self.included(other)
          other.extend(WithEvents::FixedTypes)

          other.define_method(:event_types) { self.class.event_types }
          other.define_method(:events) { @events ||= Hash.new { |h, k| h[k] = [] } }
          other.define_method(:listeners) { @listeners ||= Set.new }

          other.alias_method(:all_events, :events)
          other.alias_method(:all_listeners, :listeners)
        end

        # Helper module to define static list of valid event types
        module FixedTypes
          # Set or get the list of possible event types when attaching events
          def event_types(*list)
            list.blank? ? @event_types : @event_types =
              list.flatten.compact.map(&:to_sym).freeze
          end
        end

        # Add a new event listener for the given +event_name+. It is possible
        # to prepend the event by setting +unshift: true+. This checks if the
        # event name is a valid one due to +event_types+.
        def on(event_name, unshift: false, &block)
          event_name = event_name.to_sym
          valid = !event_types || event_types.include?(event_name)
          raise ArgumentError, <<~MSG.squish unless valid
            The #{event_name} is not a valid event type.
          MSG

          listeners << event_name
          events[event_name].send(unshift ? :unshift : :push, block)
        end
      end
    end
  end
end
