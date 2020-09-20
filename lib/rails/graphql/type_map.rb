# frozen_string_literal: true

require 'concurrent/map'

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
      mattr_accessor :base_classes, instance_writer: false,
        default: { Directive: false, Type: false }

      delegate :clear, to: :@index

      def self.loaded!(base_class)
        base_classes[base_class] = true
      end

      def initialize
        @objects = 0  # Number of types and directives defined
        @aliases = 0  # Number of symbolized aliases

        # Registerable classes that are pending registration with their given
        # source location
        @pending = []
        @callbacks = Hash.new { |h, k| h[k] = [] }

        @index = Concurrent::Map.new do |h, key|                  # Namespaces
          base_class = Concurrent::Map.new do |h, key|            # Base classes
            ensue_base_class!(key)
            h.fetch_or_store(key, Concurrent::Map.new)            # Items
          end

          h.fetch_or_store(key, base_class)
        end
      end

      # Checks if a given key or name is already defined under the same base
      # class and namespace. If +exclusive+ is set to +false+, then it won't
      # check the +:base+ namespace when not found on the given namespace.
      def exist?(name_or_key, base_class: :Type, namespaces: :base, exclusive: false)
        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)
        namespaces += [:base] unless exclusive
        namespaces.any? { |namespace| @index[namespace][base_class].key?(name_or_key) }
      end

      # Find if a given object is already defined. If +exclusive+ is set to
      # +false+, then it won't check the +:base+ namespace
      def object_exist?(object, **xargs)
        xargs[:base_class] = find_base_class(object)
        xargs[:namespaces] ||= object.namespaces
        exist?(object.gql_name, **xargs)
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

        catch :found do
          namespaces.find do |namespace|
            possibilities.find do |item|
              result = dig(namespace, xargs.fetch(:base_class, :Type), key_or_name)
              throw :found, result unless result.nil?
            end
          end
        end&.call
      ensure
        skip_register.pop
      end

      # Mark the given object to be registered later, when a fetch is triggered
      def postpone_registration(object)
        source = caller(3).find { |item| !(item =~ FILTER_REGISTER_TRACE) }
        @pending << [object, source]
      end

      # Register a given object, which must be a class where the namespaces and
      # the base class can be inferred
      def register(object)
        namespaces = object.namespaces.to_a
        base_namespace = namespaces.shift || :base
        base_class = find_base_class(object)
        ensue_base_class!(base_class)

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

        # Update counters
        @aliases += namespaces.size + object.aliases.size
        @objects += 1

        # Register the main type object
        add(base_namespace, base_class, object_key, -> { object })

        # Register all the aliases plus the object name
        [object_name, *object.aliases].each do |alias_name|
          add(base_namespace, base_class, alias_name, alias_proc)
        end

        # For each remaining namespace, register a key and a name alias
        namespaces.product([object_key, object_name]) do |(namespace, key_or_name)|
          add(namespace, base_class, key_or_name, alias_proc)
        end

        # Return the object for chain purposes
        object
      end

      # Register an item alias. Either provide a block that trigger the fetch
      # method to return that item, or a key from the same namespace and base
      # class
      def register_alias(name_or_key, key = nil, base_class: :Type, namespace: :base, &block)
        raise ArgumentError, <<~MSG.squish unless key.nil? ^ block.nil?
          Provide either a key or a block in order to register an alias.
        MSG

        ensue_base_class!(base_class)

        block ||= -> do
          fetch(key, base_class: base_class, namespaces: [namespace], exclusive: true)
        end

        add(namespace, base_class, name_or_key, block)
        @aliases += 1 if name_or_key.is_a?(Symbol)
      end

      # Iterate over the types of the given +base_class+ that are defined on the
      # given +namespaces+.
      def each_from(namespaces, base_class: :Type, &block)
        register_pending!

        namespaces = namespaces.is_a?(Set) ? namespaces.to_a : Array.wrap(namespaces)
        namespaces += [:base] unless namespaces.include?(:base)

        enumerator = Enumerator::Lazy.new(namespaces) do |yielder, *values|
          next unless @index.key?(values.last)
          iterated = []

          # Only iterate over string based types
          @index[values.last][base_class].each do |key, value|
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
            @aliases=#{@aliases}
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

          skip, keep, validate = skip_register.flatten, [], []
          while (klass, source = @pending.shift)
            next if klass.registered?

            skip.include?(klass) \
              ? keep << [klass, source] \
              : validate << klass.register!
          end

          validate.compact.each(&:call)
          @pending = keep.presence || []
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{source}"
          @pending = keep + @pending
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
        def ensue_base_class!(key)
          raise ArgumentError, <<~MSG.squish unless base_classes.keys.include?(key)
            Unsupported base class "#{key.inspect}".
          MSG
        end
    end
  end
end
