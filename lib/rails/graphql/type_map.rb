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
      # Store all the base classes and if they were eager loaded by the type map
      mattr_accessor :base_classes, instance_writer: false, default: {
        Directive: false,
        Mutation:  false,
        Type:      false,
      }

      def self.loaded!(base_class)
        base_classes[base_class] = true
      end

      def initialize
        @objects = 0  # Number of types and directives defined
        @aliases = 0  # Number of symbolized aliases

        # Registerable classes that are pending registration with their given
        # source location
        @pending = []

        @index = Concurrent::Map.new do |h, key|                  # Namespaces
          base_class = Concurrent::Map.new do |h, key|            # Base classes
            ensue_base_class!(key)
            h.fetch_or_store(key, Concurrent::Map.new)            # Items
          end

          h.fetch_or_store(key, base_class)
        end
      end

      # Checks if a given key or name is already defined under the same base
      # class and namespace. If +exclusive+ is set to +true+, then it won't
      # check the +:base+ namespace when not found on the given namespace.
      #
      # It triggers object_exist? if the +name_or_key+ is actually a reference
      # to a class
      def exist?(name_or_key, base_class: :Type, namespace: :base, exclusive: false)
        return object_exist?(name_or_key) if name_or_key.is_a?(Module)

        @index[namespace][base_class].key?(name_or_key) || !exclusive &&
          @index[:base][base_class].key?(name_or_key)
      end

      # Find if a given object is already defined. If +exclusive+ is set to
      # +true+, then it won't check the +:base+ namespace
      def object_exist?(object, exclusive: false)
        base_class = find_base_class(object)
        namespaces = object.namespaces.to_a
        namespaces << :base unless exclusive

        object_key = object.to_sym
        namespaces.any? { |namespace| @index[namespace][base_class].key?(object_key) }
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
      # namespace or in the base +:base+ namepsace
      def fetch(key_or_name, base_class: :Type, namespaces: nil, exclusive: false)
        register_pending!

        namespaces = namespaces.to_a
        namespaces += [:base] unless exclusive
        namespaces.find do |namespace|
          result = dig(namespace, base_class, key_or_name)
          break result unless result.nil?
        end&.call
      end

      # Mark the given object to be registered later, when a fetch is triggered
      def postpone_registration(object)
        source = caller(3).reject { |item| item.end_with?("`inherited'") }.first
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
        object_key = object_name.underscore.to_sym
        alias_proc = -> do
          namespaces = [base_namespace]
          fetch(object_key, base_class: base_class, namespaces: namespaces, exclusive: true)
        end

        # Update counters
        @aliases += namespaces.size + object.aliases.size
        @objects += 1

        # Register the main type object
        @index[base_namespace][base_class][object_key] = -> { object }

        # Register all the aliases plus the object name
        [object_name, *object.aliases].each do |alias_name|
          @index[base_namespace][base_class][alias_name] = alias_proc
        end

        # For each remaining namepsace, register a key and a name alias
        namespaces.product([object_key, object_name]) do |(namespace, key_or_name)|
          @index[namespace][base_class][key_or_name] = alias_proc
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

        @index[namespace][base_class][name_or_key] = block
        @aliases += 1
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

        # Clear the pending list of classes to be registered
        def register_pending!
          while (klass, source = @pending.shift)
            klass.register!
          end
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{source}"
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
        # doens't inherit any other class (superclass is equal Object)
        def find_base_class(object)
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
