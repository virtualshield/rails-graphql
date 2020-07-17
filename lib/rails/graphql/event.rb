# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Event
    #
    # This class is responsible for managing directive events, from validating
    # to triggering and executing.
    class Event
      attr_reader :source, :extra, :name

      # The list of available events
      LIST = %i[attach organize prepare finalize
        query mutation subscription request].freeze

      TRIGGER_TYPES = {
        all?: :trigger_all,
        stack?: :trigger_all,
        object?: :trigger_object,
        single?: :trigger,
      }

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
        # +phase+ of the execution and any +xargs+ information.
        def trigger(object, event_name, source, phase, **xargs, &block)
          extra = xargs.slice!(*TRIGGER_TYPES.keys)
          method_name = xargs.find { |k, v| break TRIGGER_TYPES[k] if v } || :trigger
          new(event_name, source, phase, **extra, &block).public_send(method_name, *object)
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

          # Translate callback filters options into actual filters that skip
          # the call of the callback.
          def callback_filters(filters)
            filters.map do |type, value|
              value = Array.wrap(value)
              case type
              when :during
                "return unless #{value.inspect}.include?(extra[:phase])"
              when :for
                value.map! { |item| item.is_a?(Module) ? item.name : item }
                "return unless #{value.inspect}.any? { |item| source_klass <= item }"
              end
            end.compact
          end
      end

      def initialize(name, source, phase, **extra, &block)
        @contextualize = block
        @source = source
        @extra = extra.merge(phase: phase, owner: source, event: self)
        @name = name
      end

      # Either run the +contextualize+ block or run from the +source+ POV
      def instance_exec(*args, **xargs, &block)
        context = super(&@contextualize) if @contextualize.present?
        context ||= @source

        args.unshift(self) if block.parameters.first&.last.eql?(:event) &&
          args.first != self

        context.instance_exec(*args, **xargs, &block)
      end

      # Trigger the current event for all the given +objects+. Works very
      # similar to +trigger+ with the addition of
      # +throw :stack, *optional_data+ or +event.stop(*result, level: :stack)+
      # to end the trigger for all the objects
      def trigger_all(*objects)
        catch(:stack) do
          objects.flatten.each { |object| trigger_object(object) }
        end
      end

      # Trigger the current event for all directives of given +object+. Works
      # very similar to +trigger+ with the addition of
      # +throw :object, *optional_data+ or +event.stop(*result, level: :object)+
      # to end the trigger for the current object
      def trigger_object(object)
        catch(:object) do
          object.try(:trigger_event, self)
          object = object.is_a?(GraphQL::Directive) ? [object] : object.try(:all_directives)
          object&.each { |directive| trigger(directive) }
        end
      end

      # Trigger the current event for the given +directive+. You can use
      # +throw :item, *optional_data+ or +event.stop(*result)+ as a way to
      # early return from the events.
      def trigger(directive)
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
