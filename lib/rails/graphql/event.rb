# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Event
    #
    # This class is responsible for trigerring events. It also contains the
    # +data+ that can be used on the event handlers.
    class Event
      attr_reader :source, :data, :name, :object

      delegate :[], :key?, to: :data

      # List of trigger types used on +trigger+ shortcut
      TRIGGER_TYPES = {
        all?: :trigger_all,
        stack?: :trigger_all,
        object?: :trigger_object,
        single?: :trigger,
      }

      # Event trigger shortcut that can perform any mode of trigger
      def self.trigger(event_name, object, source, **xargs, &block)
        extra = xargs.slice!(*TRIGGER_TYPES.keys)
        method_name = xargs.find { |k, v| break TRIGGER_TYPES[k] if v } || :trigger

        instance = new(event_name, source, **extra)
        instance.instance_variable_set(:@object, object) if block.present?
        instance.public_send(method_name, block || object)
      end

      def initialize(name, source, **data)
        @name = name
        @data = data.reverse_merge(event: self)
        @source = source
        @layers = []
        @iterator = data.delete(:collect?) ? :map : :each
      end

      # Return a given +name+ information from the event
      def parameter(name)
        respond_to?(name) ? public_send(name) : data[name]
      end

      # Check if the event has a given +name+ information
      def parameter?(name)
        respond_to?(name) || key?(name)
      end

      # From the list of all given objects, run the +trigger_object+
      def trigger_all(*objects)
        catchable(:stack) do
          objects.flatten.send(@iterator) do |object|
            trigger_object(object)
          end
        end
      end

      # Fetch all the events from the object, get only the ones that are from
      # the same name as the instance of this class and call +trigger+. It runs
      # in reverse order, so first in first out
      def trigger_object(object)
        @object = object
        catchable(:object) do
          object.all_events[name]&.reverse.send(@iterator) do |block|
            trigger(block)
          end
        end
      ensure
        @object = nil
      end

      # Call a given block and send the event as reference
      def trigger(block)
        block.call(self)
      end

      # Stop the execution of an event using a given +layer+. The default is to
      # get the last activated layer and stop it
      def stop(*result, layer: nil)
        throw(layer || @layers.last, *result)
      end

      private

        # Add the layer, exec the block and remove the layer
        def catchable(layer)
          @layers << layer
          yield
        ensure
          @layers.pop
        end
    end
  end
end
