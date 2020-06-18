# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Event
    #
    # This class is responsible for managing directive events, from validating
    # to triggering and executing.
    class Event
      attr_reader :source, :extra, :name

      # The list of available events and to what
      LIST = %i[attach].freeze

      class << self
        # This helps to build a event callback, which validates and also
        # disassemble the block arguments, facilitating the definition.
        #
        # ==== Options
        #
        # * <tt>:during</tt> - Run the event only for the given phase, which can
        #   be +:definition+ or +:execution+.
        # * <tt>:for</tt> - Run the event only if the class of the source object
        #   is one of the given list.
        def prepare(event_name, callback = nil, **filters, &block)
          raise ArgumentError, <<~MSG.squish unless LIST.include?(event_name)
            The #{event_name.inspect} event name is invalid. Make sure to use symbols.
          MSG

          ehance_callback_caller(callback || block, filters)
        end

        # Trigger a given +event_name+ on a given +object+ providing the
        # +phase+ of the execution and any +extra+ information.
        def trigger(object, event_name, source, phase, all: false, **extra, &block)
          method_name = all ? :trigger_all : :trigger_for
          new(event_name, source, phase, **extra).public_send(method_name, object, &block)
        end

        private

          # This allows an easy way to catch params for callbacks by "requiring"
          # specific informations using the arguments names.
          def ehance_callback_caller(callback, filters)
            params = callback_params(callback)
            filters = callback_filters(filters)
            callback.tap do |callback|
              callback.instance_eval <<~RUBY, __FILE__, __LINE__ + 1
                def prepare(source, **extra)
                  source_klass = source.is_a?(::Module) ? source : source.class
                  #{filters.join("\n  ")}
                  args = []
                  #{params.join("\n  ")}
                  args
                end
              RUBY
            end
          end

          # Translate callback parameters into actual parameters comming from
          # the source or the keyed arguments.
          def callback_params(callback)
            callback.parameters.map do |(type, item)|
              next if type != :opt
              next "args << source" if item.eql?(:source)
              "args << (source.try(:#{item}) || extra[:#{item}])"
            end.compact
          end

          # Translate callback callback filters options into actual filters that
          # skip the call of the callback.
          def callback_filters(filters)
            filters.map do |type, value|
              value = Array.wrap(value).inspect
              case type
              when :during
                "return unless #{value}.include?(extra[:phase])"
              when :for
                "return unless #{value}.any? { |item| source_klass <= item }"
              end
            end.compact
          end
      end

      def initialize(name, source, phase, **extra)
        @source = source
        @extra = extra.merge(phase: phase, owner: source, event: self)
        @name = name
      end

      # Trigger the current event for all the given +objects+. Works very
      # similar to +trigger_for+ with the addiotn of
      # +throw :stack, *optional_result+ or +event.stop(*result, level: :stack)+
      # to end the trigger for all the objects
      def trigger_all(*objects, &block)
        catch(:stack) do
          objects.flatten.each do |item|
            items = item.is_a?(GraphQL::Directive) ? [item] : item.directives
            items.each do |directive|
              result = trigger_for(directive)
              block.call(*result) if block.present?
            end
          end
        end
      end

      # Trigger the current event for the given +directive+. You can use
      # +throw :item, *optional_result+ or +event.stop(*result)+ as a way to
      # early return from the events.
      def trigger_for(directive)
        catch(:item) { directive.trigger(name, source, **extra) }
      end

      # Stop the propagation of the event by using a +throw+. Any extra argument
      # provided will be returned to the trigger of the event.
      def stop(*result, level: :item)
        throw(level, *result)
      end
    end
  end
end
