# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Event
    #
    # This class is responsible for trigerring events. It also contains the
    # +data+ that can be used on the event handlers.
    class Event
      attr_reader :source, :data, :name, :object, :last_result

      alias event itself

      # List of trigger types used on +trigger+ shortcut
      TRIGGER_TYPES = {
        all?: :trigger_all,
        stack?: :trigger_all,
        object?: :trigger_object,
        single?: :trigger,
      }.freeze

      # Event trigger shortcut that can perform any mode of trigger
      def self.trigger(event_name, object, source, **xargs, &block)
        extra = xargs.slice!(*TRIGGER_TYPES.keys)
        fallback = extra.delete(:fallback_trigger!) || :trigger
        method_name = xargs.find { |k, v| break TRIGGER_TYPES[k] if v } || fallback

        instance = new(event_name, source, **extra)
        instance.instance_variable_set(:@object, object) if block.present?
        instance.public_send(method_name, block || object)
      end

      def initialize(name, source, **data)
        @collect = data.delete(:collect?)
        @reverse = data.delete(:reverse?)

        @name = name
        @data = data
        @source = source
        @layers = []
      end

      # Return a given +name+ information from the event
      def parameter(name)
        respond_to?(name) ? public_send(name) : data[name]
      end

      alias [] parameter

      # Check if the event has a given +name+ information
      def parameter?(name)
        respond_to?(name) || data.key?(name)
      end

      alias key? parameter?

      # Temporarily attach the event into an instance ensuring to set the
      # previous value back
      def set_on(instance, &block)
        send_args = block.arity.eql?(1) ? [instance] : []
        old_event = instance.instance_variable_get(:@event) \
          if instance.instance_variable_defined?(:@event)

        return block.call(*send_args) if old_event === self

        begin
          instance.instance_variable_set(:@event, self)
          block.call(*send_args)
        ensure
          instance.instance_variable_set(:@event, old_event)
        end
      end

      # From the list of all given objects, run the +trigger_object+
      def trigger_all(*objects)
        catchable(:stack) do
          iterator = @collect ? :map : :each
          objects.flatten.send(iterator, &method(:trigger_object))
        end
      end

      # Fetch all the events from the object, get only the ones that are from
      # the same name as the instance of this class and call +trigger+. It runs
      # in reverse order, so first in first out. Since events can sometimes be
      # cached, using +events+ avoid calculating the +all_events+
      def trigger_object(object, events = nil)
        @items ||= nil
        @object ||= nil
        @last_result ||= nil

        old_items, old_object, old_result, @object = @items, @object, @last_result, object

        catchable(:object) do
          events ||= object.all_events.try(:[], name)
          stop if events.blank?

          @items = @reverse ? events.reverse_each : events.each
          call_next while @items.peek
        rescue StopIteration
          # TODO: Make sure that the +@collect+ works
          return @last_result
        end
      ensure
        @items = old_items
        @object = old_object
        @last_result = old_result
      end

      # Call a given block and send the event as reference
      def trigger(block)
        @last_result = catchable(:item) { block.call(self) }
      end

      # Stop the execution of an event using a given +layer+. The default is to
      # get the last activated layer and stop it
      def stop(*result, layer: nil)
        layer = @layers[layer] if layer.is_a?(Numeric)
        throw(layer || @layers.first, *result)
      end

      # Call the next item on the queue and return its result
      def call_next
        trigger(@items.next)
      rescue StopIteration
        # Do not do anything when missing next/super
      end

      alias call_super call_next

      protected

        alias args_source itself

      private

        # Add the layer, exec the block and remove the layer
        def catchable(layer)
          @layers.unshift(layer)
          catch(layer) { yield }
        ensure
          @layers.shift
        end

        # Check for data based readers
        def respond_to_missing?(method_name, include_private = false)
          data.key?(method_name) || super
        end

        # If the +method_name+ matches any key entry of the provided data, just
        # return the value stored there
        def method_missing(method_name, *)
          data.key?(method_name) ? data[method_name] : super
        end
    end
  end
end
