# frozen_string_literal: true

require 'concurrent/map'
require 'active_support/core_ext/class/subclasses'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Type Map
    #
    # Inspired by ActiveRecord::Type::TypeMap, this class stores all the things
    # defined, their unique name, their basic settings, and correctly index
    # them so they are easy to find whenever necessary.
    #
    # Items are stored as procs because aliases should fetch whatever the base
    # object is, even if they change in the another point.
    #
    # The cache stores in the following structure:
    # Namespace -> BaseClass -> ItemKey -> Item
    class TypeMap
      FILTER_REGISTER_TRACE = /((inherited|initialize)'$|schema\.rb:\d+)/.freeze

      # Store all the base classes and if they were eager loaded by the type map
      # Be aware of the order because hard reset is based in this order
      mattr_accessor :base_classes, instance_writer: false, default: {
        Type: false,
        Directive: false,
        Schema: false,
      }

      def self.loaded!(base_class)
        base_classes[base_class] = true
      end

      # Reset the state of the type mapper
      def reset!
        @objects = 0 # Number of types and directives defined

        @pending = []
        @callbacks = Hash.new { |h, k| h[k] = [] }
        @skip_register = nil

        @index = Concurrent::Map.new do |h1, key1|                # Namespaces
          base_class = Concurrent::Map.new do |h2, key2|          # Base classes
            ensure_base_class!(key2)
            h2.fetch_or_store(key2, Concurrent::Map.new)          # Items
          end

          h1.fetch_or_store(key1, base_class)
        end

        @checkpoint.map(&:register!) if defined?(@checkpoint)
      end

      alias initialize reset!

      # This will do a full reset of the type map, re-registering all the
      # descendant classes for all the base classes
      def hard_reset!
        remove_instance_variable(:@checkpoint) if defined?(@checkpoint)

        reset!
        base_classes.each_key do |base_class|
          GraphQL.const_get(base_class).descendants.each(&:register!)
        end
      end

      # Save or restore a checkpoint that can the type map can be reseted to
      # TODO: With hard reset, we might not need checkpoint anymore
      def use_checkpoint!
        return reset! if defined?(@checkpoint)

        register_pending!
        @checkpoint = objects
      end

      # Get the list of all registred objects
      def objects(base_classes: nil, namespaces: nil)
        (Array.wrap(namespaces).presence || @index.keys).map do |namespace|
          (Array.wrap(base_classes).presence || @index[namespace].keys).map do |base_class|
            @index[namespace][base_class].values.map(&:call) \
              if @index[namespace].key?(base_class)
          end if @index.key?(namespace)
        end.flatten.compact.uniq.select do |obj|
          obj.respond_to?(:register!)
        end
      end

      # Same as +fetch+ but it will raise an exception or retry depending if the
      # base type was already loaded or not
      def fetch!(*args, base_class: :Type, **xargs)
        xargs[:base_class] = base_class

        result = fetch(*args, **xargs)
        return result unless result.nil?

        raise ArgumentError, <<~MSG.squish if base_classes[base_class]
          Unable to find #{args.first.inspect} #{base_class} object.
        MSG

        GraphQL.const_get(base_class).eager_load!
        fetch!(*args, **xargs)
      end

      # Find the given key or name inside the base class either on the given
      # namespace or in the base +:base+ namespace
      def fetch(key_or_name, prevent_register: nil, **xargs)
        if prevent_register != true
          skip_register << Array.wrap(prevent_register)
          register_pending!
        end

        namespaces = xargs[:namespaces]
        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)
        namespaces += [:base] unless xargs.fetch(:exclusive, false)

        possibilities = Array.wrap(key_or_name)
        possibilities += Array.wrap(xargs[:fallback]) if xargs.key?(:fallback)

        namespaces.uniq.find do |namespace|
          possibilities.find do |item|
            result = dig(namespace, xargs.fetch(:base_class, :Type), item)
            return result.call unless result.nil?
          end
        end
      ensure
        skip_register.pop
      end

      # Checks if a given key or name is already defined under the same base
      # class and namespace. If +exclusive+ is set to +false+, then it won't
      # check the +:base+ namespace when not found on the given namespace.
      def exist?(name_or_key, base_class: :Type, namespaces: :base, exclusive: false)
        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)
        namespaces += [:base] unless exclusive
        namespaces.uniq.any? { |namespace| dig(namespace, base_class, name_or_key).present? }
      end

      # Find if a given object is already defined. If +exclusive+ is set to
      # +false+, then it won't check the +:base+ namespace
      def object_exist?(object, **xargs)
        xargs[:base_class] = find_base_class(object)
        xargs[:namespaces] ||= object.namespaces
        exist?(object, **xargs)
      end

      # Mark the given object to be registered later, when a fetch is triggered
      # TODO: Improve this with a Backtracer Cleaner
      def postpone_registration(object)
        source = caller(3).find { |item| item !~ FILTER_REGISTER_TRACE }
        @pending << [object, source]
      end

      # Register a given object, which must be a class where the namespaces and
      # the base class can be inferred
      def register(object)
        namespaces = object.namespaces.dup
        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)

        base_namespace = namespaces.shift || :base
        base_class = find_base_class(object)
        ensure_base_class!(base_class)

        # Cache the name, the key, and the alias proc
        object_name = object.gql_name
        object_key = object.to_sym
        alias_proc = -> do
          fetch(object_key,
            base_class: base_class,
            namespaces: base_namespace,
            exclusive: true,
          )
        end

        # Register the main type object
        add(base_namespace, base_class, object_key, -> { object })

        # Register all the aliases plus the object name
        aliases = object.try(:aliases) || []
        [object_name, *aliases].each do |alias_name|
          add(base_namespace, base_class, alias_name, alias_proc)
        end

        # For each remaining namespace, register a key and a name alias
        namespaces.product([object_key, object_name, *aliases]) do |(namespace, key_or_name)|
          add(namespace, base_class, key_or_name, alias_proc)
        end

        # Return the object for chain purposes
        @objects += 1
        object
      end

      # Register an item alias. Either provide a block that trigger the fetch
      # method to return that item, or a key from the same namespace and base
      # class
      def register_alias(name_or_key, key = nil, **xargs, &block)
        raise ArgumentError, <<~MSG.squish unless key.nil? ^ block.nil?
          Provide either a key or a block in order to register an alias.
        MSG

        base_class = xargs.delete(:base_class) || :Type
        ensure_base_class!(base_class)

        namespaces = xargs.delete(:namespaces) || []
        namespaces = namespaces.to_a if namespaces.is_a?(Set)
        namespaces << xargs.delete(:namespace)

        namespaces = namespaces.compact.presence || [:base]

        block ||= -> do
          fetch(key, base_class: base_class, namespaces: namespaces, exclusive: true)
        end

        namespaces.each { |ns| add(ns, base_class, name_or_key, block) }
      end

      # Iterate over the types of the given +base_class+ that are defined on the
      # given +namespaces+.
      def each_from(namespaces, base_class: :Type, exclusive: false, &block)
        register_pending!

        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)
        namespaces += [:base] unless namespaces.include?(:base) || exclusive

        iterated = []
        enumerator = Enumerator::Lazy.new(namespaces.uniq) do |yielder, item|
          next unless @index.key?(item)

          # Only iterate over string based types
          @index[item][base_class]&.each do |_key, value|
            next if iterated.include?(value = value.call) || value.blank?
            iterated << value
            yielder << value
          end
        end

        block.present? ? enumerator.each(&block) : enumerator
      end

      # Add a callback that will trigger when a type is registered under the
      # given set of settings of this method
      def after_register(name_or_key, base_class: :Type, namespaces: :base, &block)
        item = fetch(name_or_key,
          prevent_register: true,
          base_class: base_class,
          namespaces: namespaces,
        )

        return block.call(item) unless item.nil?

        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)
        position = callbacks[name_or_key].size

        callbacks[name_or_key] << ->(n, b, result) do
          return unless b === base_class && namespaces.include?(n)
          block.call(result)
          position
        end
      end

      def inspect # :nodoc:
        <<~INFO.squish + '>'
          #<Rails::GraphQL::TypeMap [index]
            @namespaces=#{@index.size}
            @base_classes=#{base_classes.size}
            @objects=#{@objects}
            @pending=#{@pending.size}
        INFO
      end

      private

        attr_reader :callbacks

        # Add a item to the index and then trigger the callbacks if any
        def add(namespace, base_class, key, raw_result)
          @index[namespace][base_class][key] = raw_result
          return unless callbacks.key?(key)

          result = nil
          removeables = callbacks[key].map do |callback|
            callback.call(namespace, base_class, result ||= raw_result.call)
          end

          removeables.compact.reverse_each(&callbacks[key].method(:delete_at))
          callbacks.delete(key) if callbacks[key].empty?
        end

        # A list of classes to prevent the registration, since they might be
        # the source of a fetch
        def skip_register
          @skip_register ||= []
        end

        # Clear the pending list of classes to be registered
        def register_pending!
          return if @pending.blank?

          skip = skip_register.flatten
          keep = []
          validate = []

          while (klass, source = @pending.shift)
            next if klass.registered?

            if skip.include?(klass)
              keep << [klass, source]
            else
              validate << klass.register!
            end
          end

          validate.compact.each(&:call)
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{source}"
        ensure
          @pending += keep unless keep.nil?
        end

        # Since concurrent map doesn't implement this method, use this to
        # navigate through the index
        def dig(*parts)
          parts.inject(@index) do |h, key|
            break unless h.key?(key)
            h.fetch(key)
          end
        end

        # Find the base class of an object, which is basically the class that
        # doesn't inherit any other class (superclass is equal Object)
        def find_base_class(object)
          return object.base_type_class if object.respond_to?(:base_type_class)

          base_class = object
          base_class = base_class.superclass until base_class.superclass === Object
          base_class.name.demodulize.to_sym
        end

        # Make sure that the given key is a valid base class key
        def ensure_base_class!(key)
          raise ArgumentError, <<~MSG.squish unless base_classes.keys.include?(key)
            Unsupported base class "#{key.inspect}".
          MSG
        end
    end
  end
end
