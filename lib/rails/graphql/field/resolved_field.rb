# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This provides ways for fields to be resolved manually, by adding callbacks
    # and additional configurations in order to resolve a field value during a
    # request
    module Field::ResolvedField
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

        resolver_hooks[:before].public_send(unshift ? :unshift : :push, [block, args, xargs])
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

        resolver_hooks[:after].public_send(unshift ? :unshift : :push, [block, args, xargs])
      end

      alias finalize after_resolve

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
          for performing hooks: #{invalid.map(&:first).to_sentence}
        MSG

        nil # No exception already means valid
      end

      protected

        # Chedck if a given +method_name+ is callable from the owner perspective
        def callable?(method_name)
          owner.respond_to?(method_name) || owner.public_method_defined?(method_name)
        end

        # Run the resolver and return the result value
        def run_resolver(context)
          return unless dynamic_resolver?

          run_callback(@resolver || [method_name], context)
        end

        # Run all the callbacks for the given +hook+
        def run_hooks(hook, context)
          return unless resolver_hooks.key?(hook) && resolver_hooks[hook].present?

          resolver_hooks[hook].each { |callback| run_callback(callback, context) }
        end

        # Depending on the format of the callback, run it using the context
        def run_callback(callback, context)
          callback, args, xargs = callback

          return context.instance_exec(*args, **xargs, &callback) \
            if callback.is_a?(Proc)

          object = owner.is_a?(Class) ? context.instance_for(owner) : owner

          parameters = object.method(callback).parameters
          args.unshift(context) if parameters.first&.last.eql?(:resolver)

          object.public_send(callback, *args, **xargs)
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
