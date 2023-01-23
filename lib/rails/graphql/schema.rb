# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Schema
    #
    # This is a pure representation of a GraphQL schema.
    # See: http://spec.graphql.org/June2018/#SchemaDefinition
    #
    # In addition to the spec implementation, this also allows separation by
    # namespaces, where each schema is associated with one and only one
    # namespace, guiding requests and types searching.
    #
    # This class works similarly to the {TypeMap}[rdoc-ref:Rails::base_classMap]
    # class, where its purpose is to know which QueryFields, Mutations, and
    # Subscriptions are available. The main difference is that it doesn't hold
    # namespace-based objects, since each schema is associated to a single
    # namespace.
    class Schema
      extend Helpers::WithSchemaFields
      extend Helpers::WithDirectives
      extend Helpers::WithGlobalID
      extend Helpers::Registerable
      extend GraphQL::Introspection

      include ActiveSupport::Configurable
      include ActiveSupport::Rescuable
      include Helpers::Instantiable

      self.abstract = true
      self.spec_object = true
      self.directive_location = :schema

      # Imports schema specific configurations
      configure do |config|
        inherited_keys = %i[
          enable_introspection request_strategies
          enable_string_collector default_response_format
          schema_type_names cache
          default_subscription_provider default_subscription_broadcastable
        ].to_set

        config.default_proc = proc do |hash, key|
          hash[key] = GraphQL.config.send(key) if inherited_keys.include?(key)
        end
      end

      rescue_from(PersistedQueryNotFound) do |error|
        response = { errors: [{ message: +'PersistedQueryNotFound' }] }
        error.request.force_response(response, error)
      end

      class << self
        delegate :type_map, :logger, to: '::Rails::GraphQL'
        delegate :version, to: :type_map

        # :singleton-method:
        # Since there are only one schema per namespace, the name is constant
        def gql_name
          'schema'
        end

        alias graphql_name gql_name

        # :singleton-method:
        # Since there is only one schema per namespace, then both kind and
        # to_sym, which is used to register, are the same
        def kind
          :schema
        end

        alias to_sym kind

        # :singleton-method:
        # Use a soft mode to find a schema associated with a namespace
        def find(namespace)
          type_map.fetch(:schema,
            namespaces: namespace,
            base_class: :Schema,
            exclusive: true,
          )
        end

        # :singleton-method:
        # Find the schema associated to the given namespace
        def find!(namespace)
          type_map.fetch!(:schema,
            namespaces: namespace,
            base_class: :Schema,
            exclusive: true,
          )
        end

        # :singleton-method:
        # The base class of all schemas is always +Schema+
        def gid_base_class
          Schema
        end

        # :singleton-method:
        # Return the schema
        def find_by_gid(gid)
          result = find!(gid.namespace.to_sym)
          return result if gid.name.nil?

          result.find_field!(gid.scope, gid.name)
        end

        # Find all types that are available for the current schema
        def types(base_class: :Type, &block)
          type_map.each_from(namespace, base_class: base_class, &block)
        end

        # Schemas are assigned to a single namespace. You can provide a module
        # as the second argument to associate that module to the same namespace
        def set_namespace(ns, mod = nil)
          @namespace = normalize_namespaces([ns]).first
          type_map.associate(@namespace, mod) if mod.is_a?(Module)
        end

        alias set_namespaces set_namespace

        # Schemas are assigned to a single namespace and not inherited
        def namespace(*args)
          if args.present?
            set_namespace(*args)
          elsif defined?(@namespace) && !@namespace.nil?
            @namespace
          else
            :base
          end
        end

        # Add compatibility to the list of namespaces
        def namespaces
          namespace
        end

        # Return the subscription provider for the current schema
        def subscription_provider
          if !defined?(@subscription_provider)
            @subscription_provider = config.default_subscription_provider
            subscription_provider
          elsif @subscription_provider.is_a?(String)
            provider = (name = @subscription_provider).safe_constantize
            return @subscription_provider = provider.new(logger: logger) unless provider.nil?

            raise ::NameError, +"uninitialized constant #{name}"
          else
            @subscription_provider
          end
        end

        # Check if the schema is valid
        def valid?
          defined?(@validated) && @validated
        end

        # Only run the validated process if it has not yet been validated
        def validate
          validate! unless valid?
        rescue StandardError
          GraphQL.logger.warn(+"\e[1m\e[31mSchema #{name} is invalid!\e[0m")
          raise
        end

        # Run validations and then mark itself as validated
        def validate!(*)
          super if defined? super
          @validated = true
        end

        # Check if the class is already registered in the type map
        def registered?
          type_map.object_exist?(self, exclusive: true)
        end

        # The process to register a class and it's name on the index
        def register!
          return if self == GraphQL::Schema
          return super unless registered?

          current = type_map.fetch(:schema,
            namespaces: namespace,
            base_class: :Schema,
            exclusive: true,
          )

          raise ArgumentError, (+<<~MSG).squish
            The #{namespace.inspect} namespace is already assigned to "#{current.name}".
            Please change the namespace for "#{klass.name}" class.
          MSG
        end

        # Hook into the unregister process to reset the subscription provider
        def unregister!
          restart_subscriptions
          super
        end

        # Find a given +type+ associated with the schema
        def find_type(type, **xargs)
          xargs[:base_class] = :Type
          xargs[:namespaces] = namespaces
          type_map.fetch(type, **xargs)
        end

        # Find a given +type+ associated with the schema. It will raise an
        # exception if the +type+ can not be found
        def find_type!(type, **xargs)
          xargs[:base_class] = :Type
          xargs[:namespaces] = namespaces
          type_map.fetch!(type, **xargs)
        end

        # Find a given +directive+ associated with the schema. It will raise an
        # exception if the +directive+ can not be found
        def find_directive!(directive, **xargs)
          xargs[:base_class] = :Directive
          xargs[:namespaces] = namespaces
          type_map.fetch!(directive, **xargs)
        end

        # Remove subscriptions by their provided +sids+
        def remove_subscriptions(*sids)
          subscription_provider&.remove(*sids)
        end

        # Add a new subscription using all the provided request subscription
        # objects
        def add_subscriptions(*subscriptions)
          subscription_provider.add(*subscriptions)
        end

        # The the schema is unloaded, we need to make sure that the provider
        # can smoothly shutdown itself
        def restart_subscriptions
          return unless defined?(@subscription_provider) && !@subscription_provider.nil?
          subscription_provider.shutdown
        end

        # Checks if the given +operation+ can be subscribed to
        def accepts_subscription?(operation)
          subscription_provider.accepts?(operation)
        end

        # This receives a request subscription object and return an id for that.
        # By default, it just produces a random uuid
        def subscription_id_for(*)
          SecureRandom.uuid
        end

        # Simple delegator to the cache store set on the schema config, mapped
        # to +exist?+
        def cached?(name, options = nil)
          config.cache.exist?(expand_cache_key(name), options)
        end

        # Simple delegator to the cache store set on the schema config, mapped
        # to +delete+
        def delete_from_cache(name, options = nil)
          config.cache.delete(expand_cache_key(name), options)
        end

        # Simple delegator to the cache store set on the schema config, mapped
        # to +read+
        def read_from_cache(name, options = nil)
          config.cache.read(expand_cache_key(name), options)
        end

        # Simple delegator to the cache store set on the schema config, mapped
        # to +write+
        def write_on_cache(name, value, options = nil)
          config.cache.write(expand_cache_key(name), value, options)
        end

        # Simple delegator to the cache store set on the schema config, mapped
        # to +fetch+
        def fetch_from_cache(name, options = nil)
          config.cache.fetch(expand_cache_key(name), options)
        end

        # Describe a schema as a GraphQL string
        def to_gql(**xargs)
          ToGQL.describe(self, **xargs)
        end

        protected

          attr_writer :subscription_provider

          # Mark the given class to be pending of registration
          def inherited(subclass)
            subclass.spec_object = false
            subclass.abstract = false
            super if defined? super

            # The only way to actually get the namespace into the cache prefix
            subclass.config.define_singleton_method(:cache_prefix) do
              self[:cache_prefix] ||= "#{GraphQL.config.cache_prefix}#{subclass.namespace}/"
            end
          end

          # Indicate to type map that the current schema depends on all the
          # files in the provided +path+ directory
          def load_directory(dir = '.', recursive: true)
            source = caller_locations(2, 1).first.path

            absolute = dir.start_with?(File::SEPARATOR)
            path = recursive ? File.join('**', '*.rb') : '*.rb'
            dir = File.expand_path(dir, File.dirname(source)) unless absolute

            list = Dir.glob(File.join(dir, path)).select do |file_name|
              file_name != source
            end

            type_map.add_dependencies(list, to: namespace)
          end

          alias load_current_directory load_directory

          # Load a list of known dependencies based on the given +type+
          def load_dependencies(type, *list)
            GraphQL.add_dependencies(type, *list, to: namespace)
          end

          # A syntax sugar for +load_dependencies(:directive, *list)+
          def load_directives(*list)
            load_dependencies(:directive, *list)
          end

          # A syntax sugar for +load_dependencies(:source, *list)+
          def load_sources(*list, build: false)
            load_dependencies(:source, *list)
            build_all_sources if build
          end

          # Build all sources that has the belongs to the current namespace
          def build_all_sources
            GraphQL::Source.descendants.each do |klass|
              next if klass.abstract?

              ns = klass.namespaces
              klass.build_all if (ns.blank? && namespace == :base) ||
                ns == namespace || ns.try(:include?, namespace)
            end
          end

          # Make sure to prefix the cache key
          def expand_cache_key(name)
            if name.is_a?(String)
              name = +"#{config.cache_prefix}#{name}"
            elsif name.respond_to?(:cache_key=)
              name.cache_key = +"#{config.cache_prefix}#{name.cache_key}"
            end

            name
          end

          # Generate the helper methods to easily create types within the
          # definition of the schema
          GraphQL::Type::KINDS.each do |kind|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def load_#{kind.underscore.pluralize}(*list)
                load_dependencies(:#{kind.underscore}, *list)
              end

              def #{kind.underscore}(name, **xargs, &block)
                create_type(name, :#{kind}, **xargs, &block)
              end
            RUBY
          end

          # Helper method to create a single source
          def source(object, superclass = nil, build: true, **xargs, &block)
            superclass ||= GraphQL::Source.find_for!(object)

            xargs[:suffix] = 'Source'
            create_and_build = build
            schema_namespace = namespace

            create_klass(object, superclass, GraphQL::Source, **xargs) do
              set_namespace schema_namespace

              xargs.each do |key, value|
                _, segment = key.to_s.split('skip_on_')
                skip_on segment, value if segment.present?
              end

              instance_exec(&block) if block.present?
              build_all if create_and_build
            end
          end

          # Helper method to create multiple sources with the same type
          def sources(*list, of_type: nil, build: true, &block)
            list = list.flatten

            of_type ||= GraphQL::Source.find_for!(list.first)
            list.each { |object| source(object, of_type, build: build, &block) }
          end

          # A simpler way to create a new type object without having to create
          # a class in a different file
          def create_type(name, superclass, **xargs, &block)
            superclass = GraphQL::Type.const_get(superclass) unless superclass.is_a?(Module)
            xargs[:suffix] ||= superclass.base_type.name.demodulize

            create_klass(name, superclass, GraphQL::Type, **xargs, &block)
          end

        private

          # Helper to create objects that are actually classes of a given
          # +superclass+ ensuring that it inherits from +base_class+.
          #
          # The +suffix+ option can ensures that the name of the created
          # class ends with a specific suffix.
          def create_klass(name_or_object, superclass, base_class = nil, **xargs, &block)
            name = name_or_object.is_a?(Module) ? name_or_object.name : name_or_object.to_s

            base_module = name.classify.deconstantize
            base_module.prepend('GraphQL::') unless base_module =~ /^GraphQL(::|$)/
            base_module = base_module.delete_suffix('::').constantize

            klass_name = name.classify.demodulize
            klass_name += xargs[:suffix] if xargs.key?(:suffix) &&
              !klass_name.end_with?(xargs[:suffix])

            if base_module.const_defined?(klass_name)
              klass = base_module.const_get(klass_name)

              raise DuplicatedError, (+<<~MSG).squish unless !xargs[:once] && klass < superclass
                A constant named "#{klass_name}" already exists for the
                "#{base_module.name}" module.
              MSG

              # This likely happened because the classes are being reloaded, so
              # call inherited again as if the class has just been created
              superclass.inherited(klass)
            else
              base_class ||= superclass.ancestors.find { |k| k.superclass === Class }

              valid = superclass.is_a?(Module) && superclass < base_class
              raise DefinitionError, (+<<~MSG).squish unless valid
                The given "#{superclass}" superclass does not inherites from
                #{base_class.name} class.
              MSG

              klass = base_module.const_set(klass_name, Class.new(superclass))
            end

            klass.abstract = xargs[:abstract] if xargs.key?(:abstract)
            klass.assigned_to = name_or_object if name_or_object.is_a?(Module) &&
              klass.is_a?(Helpers::WithAssignment)

            klass.set_namespace(namespace)
            klass.module_exec(&block) if block.present?
            klass
          end
      end
    end
  end
end
