# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module that allows other objects to hold events, either from a
      # singleton point-of-view, or for instances
      module WithEvents
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.extend(WithEvents::FixedTypes)

          other.inherited_collection(:events, type: :hash_array)
          other.inherited_collection(:listeners)
        end

        def self.included(other)
          other.extend(WithEvents::FixedTypes)
          other.delegate(:event_types, to: :class)

          other.define_method(:events) { @events ||= Hash.new { |h, k| h[k] = [] } }
          other.define_method(:listeners) { @listeners ||= Set.new }
        end

        # Helper module to define static list of valid event types
        module FixedTypes
          # Set or get the list of possible event types when attaching events
          def event_types(*list, append: false, expose: false)
            return (defined?(@event_types) && @event_types.presence) ||
              superclass.try(:event_types) || [] if list.blank?

            new_list = append ? event_types : []
            new_list += list.flatten.compact.map(&:to_sym)
            @event_types = new_list.uniq.freeze
            expose_events!(*list) if expose
            @event_types
          end

          protected

            # Auxiliar method that creates easy-accessible callback assignment
            def expose_events!(*list)
              list.each do |event_name|
                next if method_defined?(event_name)
                define_method(event_name) do |*args, **xargs, &block|
                  on(event_name, *args, **xargs, &block)
                end
              end
            end
        end

        # Mostly for correct inheritance on instances
        def all_events
          current = defined?(@events) ? @events : {}
          return current unless defined? super
          Helpers.merge_hash_array(current, super)
        end

        # Mostly for correct inheritance on instances
        def all_listeners
          current = (defined?(@listeners) && @listeners) || Set.new
          defined?(super) ? (current + super) : current
        end

        # Add a new event listener for the given +event_name+. It is possible
        # to prepend the event by setting +unshift: true+. This checks if the
        # event name is a valid one due to +event_types+.
        def on(event_name, unshift: false, &block)
          event_name = event_name.to_sym
          valid = !event_types || event_types.include?(event_name)
          raise ArgumentError, (+<<~MSG).squish unless valid
            The #{event_name} is not a valid event type.
          MSG

          listeners << event_name
          events[event_name].send(unshift ? :unshift : :push, block)
        end
      end
    end
  end
end
