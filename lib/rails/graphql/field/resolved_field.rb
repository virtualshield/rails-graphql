# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This provides ways for fields to be resolved manually, by adding callbacks
    # and additional configurations in order to resolve a field value during a
    # request
    module Field::ResolvedField
      ALIAS_KEYS = { before: :prepare, after: :finalize }.freeze

      # If the field has a resolver, then it can't be serialized from Active
      # Record
      def from_ar?(*)
        dynamic_resolver? ? false : super
      end

      # If the field has a resolver, then it can't be serialized from Active
      # Record
      def from_ar(*)
        dynamic_resolver? ? false : super
      end

      # Return the list of resolver hook keys plus a conditional resolver key
      def listeners
        ((super if defined? super) || []) + resolver_hooks.keys
      end

      # Add support for event based trigger of hooks
      def trigger_event(event)
        run(event.name, event)
      end

      # Add a before resolve callback. Either provide a +method_name+ that will
      # be triggered on the +owner+ or a +block+ to be executed. Use +unshift+
      # to prepend the method in the order.
      def before_resolve(method_name = nil, *args, unshift: false, **xargs, &block)
        raise ::ArgumentError, <<~MSG.squish if method_name.present? && block.present?
          Provide only a block or a method name, not both at the same time.
        MSG

        if method_name.present?
          valid_format = method_name.is_a?(Symbol) || method_name.is_a?(Proc)
          raise ::ArgumentError, <<~MSG.squish unless valid_format
            The given #{method_name.class.name} class is not a valid callback.
          MSG

          block = method_name
        end

        method_name = unshift ? :unshift : :push
        resolver_hooks[:prepare].public_send(method_name, [block, args, xargs])
      end

      alias prepare before_resolve

      # Add a after resolve callback. Either provide a +method_name+ that will
      # be triggered on the +owner+ or a +block+ to be executed. Use +unshift+
      # to prepend the method in the order.
      def after_resolve(method_name = nil, *args, unshift: false, **xargs, &block)
        raise ::ArgumentError, <<~MSG.squish if method_name.present? && block.present?
          Provide only a block or a method name, not both at the same time.
        MSG

        if method_name.present?
          valid_format = method_name.is_a?(Symbol) || method_name.is_a?(Proc)
          raise ::ArgumentError, <<~MSG.squish unless valid_format
            The given #{method_name.class.name} class is not a valid callback.
          MSG

          block = method_name
        end

        method_name = unshift ? :unshift : :push
        resolver_hooks[:finalize].public_send(method_name, [block, args, xargs])
      end

      alias finalize after_resolve

      # This is the lowest point in the call stack for nested hooks
      def nested_hooks(hook)
        resolver_hooks.key?(hook) ? resolver_hooks[hook] : []
      end

      # Add a block that is performed while resolving a value of a field
      def resolve(*args, **xargs, &block)
        @resolver = [block, args, xargs]
      end

      # Check if the field has a dynamic resolver
      def dynamic_resolver?
        @resolver.present? || callable?(method_name)
      end

      # Run all the callbacks for the given +hook+, which can be the resolver as
      # well. Proc-based hooks will be ran from the provided context
      def run(hook, context)
        hook.eql?(:resolver) ? run_resolver(context) : run_hooks(hook, context)
      end

      # Checks if all the named callbacks can actually be called
      def validate!(*)
        super if defined? super

        invalid = resolver_hooks.values.flatten(1).reject do |(callback)|
          callback.is_a?(Proc) || callable?(callback)
        end

        raise ArgumentError, <<~MSG.squish if invalid.present?
          The "#{owner.name}" class does not define the following methods needed
          for performing hooks: #{invalid.map(&:first).to_sentence}.
        MSG

        nil # No exception already means valid
      end

      protected

        # Chedck if a given +method_name+ is callable from the owner perspective
        def callable?(method_name)
          owner.is_a?(Class) && owner.try(:gql_resolver?, method_name)
        end

        # Run the resolver and return the result value
        def run_resolver(context)
          return unless dynamic_resolver?

          run_callbacks([@resolver || [method_name]], context)
        end

        # Run all the callbacks for the given +hook+
        def run_hooks(hook, context)
          hook = ALIAS_KEYS[hook] || hook
          list = nested_hooks(hook)

          run_callbacks(list, context) unless list.empty?
        end

        # Depending on the format of the callback, run it using the context
        def run_callbacks(callbacks, context)
          object = nil
          callbacks.map do |(callback, args, xargs)|
            xargs ||= {}

            if callback.is_a?(Proc)
              args = callback_args(callback, context, args)
              context.try(:hit, context.instance_exec(*args, **xargs, &callback))
              next
            end

            object ||= owner.is_a?(Class) ? context.instance_for(owner) : owner
            callback = object.method(callback)

            context.try(:hit, callback.call(*callback_args(callback, context, args), **xargs))
          end
        end

        # A little extra configuration when actually triggering the callback
        def callback_args(callback, context, args)
          parameter = callback.parameters.first&.last
          parameter.eql?(:event) ? [context] + args : args
        end

        # Stores the hooks for the resolve callbacks
        def resolver_hooks
          @resolver_hooks ||= Hash.new { |h, k| h[k] = [] }
        end
    end

    Field::ScopedConfig.delegate :before_resolve, :after_resolve,
      :prepare, :finalize, :resolve, to: :field
  end
end
