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
    # This class works similary to the {TypeMap}[rdoc-ref:Rails::base_classMap]
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

      # The purpose of instantiating an schema is to have access to its
      # public methods. It then runs from the strategy perspective, pointing
      # out any other methods to the manually set event
      delegate_missing_to :event
      attr_reader :event

      self.abstract = true
      self.spec_object = true
      self.directive_location = :schema

      # Imports schema specific configurations
      configure do |config|
        %i[
          enable_introspection request_strategies
          enable_string_collector default_response_format
          schema_type_names
        ].each do |name|
          config_accessor(name) { GraphQL.config.send(name) }
        end
      end

      class << self
        delegate :type_map, :logger, to: '::Rails::GraphQL'

        # Mark the given class to be pending of registration
        def inherited(subclass)
          subclass.spec_object = false
          subclass.abstract = false
          super if defined? super
        end

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

        # Schemas are assigned to a single namespace
        def set_namespace(*list)
          @namespace = normalize_namespaces(list).first
        end

        alias set_namespaces set_namespace

        # Schemas are assigned to a single namespace and not inherited
        def namespace(*list)
          if list.present?
            set_namespace(*list)
          elsif defined?(@namespace) && !@namespace.nil?
            @namespace
          else
            :base
          end
        end

        # Add compatibility to the list of namespaces
        def namespaces
          Set.new([namespace])
        end

        # Check if the schema is valid
        def valid?
          !!defined?(@validated)
        end

        # Only run the validated process if it has not yet been validated
        def validate
          validate! unless valid?
        rescue StandardError
          puts (+"\e[1m\e[31mSchema #{name} is invalid!\e[0m")
          raise
        end

        # Run validations and then mark itself as validated
        def validate!(*)
          super if defined? super
          @validated = true
        end

        # Check if the class is already registered in the typemap
        def registered?
          type_map.object_exist?(self, exclusive: true)
        end

        # The process to register a class and it's name on the index
        def register!
          return if self == GraphQL::Schema

          unless registered?
            super if defined? super
            return type_map.register(self)
          end

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

        # Describe a schema as a GraphQL string
        def to_gql(**xargs)
          ToGQL.describe(self, **xargs)
        end

        protected

          # Indicate to type map that the current schema depends on all the
          # files in the provided +path+ directory
          def load_directory(dir = '.', recursive: true)
            source = caller_locations(2, 1).first.path

            absolute = dir.start_with?(File::SEPARATOR)
            path = recursive ? File.join('**', '*.rb') : '*.rb'
            dir = File.expand_path(dir, File.dirname(source)) unless absolute

            list = Dir.glob(File.join(dir, path)).select do |file_name|
              next if file_name == source
              file_name.chomp!('.rb')
            end

            type_map.add_dependencies(list, to: namespace)
          end

          # An alias to the above metho that does not accept arguments
          def load_current_directory
            load_directory
          end

          # Load a list of known dependencies based on the given +type+
          def load_dependencies(type, *list)
            ref = GraphQL.config.known_dependencies

            raise ArgumentError, (+<<~MSG).squish if (ref = ref[type]).nil?
              There are no #{type} known dependencies.
            MSG

            list = list.flatten.compact.map do |item|
              next item unless (item = ref[item]).nil?
              raise ArgumentError, (+<<~MSG).squish
                Unable to find #{item} as #{type} in known dependencies.
              MSG
            end

            type_map.add_dependencies(list, to: namespace)
          end

          # A syntax sugar for +load_dependencies(:directive, *list)+
          def load_directives(*list)
            load_dependencies(:directive, *list)
          end

          # A syntax sugar for +load_dependencies(:source, *list)+
          def load_sources(*list)
            load_dependencies(:source, *list)
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
          def source(object, superclass = nil, **xargs, &block)
            superclass ||= GraphQL::Source.find_for!(object)

            xargs[:suffix] = 'Source'
            schema_namespace = namespace
            create_klass(object, superclass, GraphQL::Source, **xargs) do
              set_namespace schema_namespace

              xargs.each do |key, value|
                _, segment = key.to_s.split('skip_on_')
                skip_on segment, value if segment.present?
              end

              instance_exec(&block) if block.present?
              build!
            end
          end

          # Helper method to create multiple sources with the same type
          def sources(*list, of_type: nil, &block)
            list = list.flatten

            of_type ||= GraphQL::Source.find_for!(list.first)
            list.each { |object| source(object, of_type, &block) }
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
            klass.instance_exec(&block) if block.present?
            klass
          end
      end
    end
  end
end
