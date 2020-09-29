# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
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
      extend Helpers::Registerable
      extend GraphQL::Introspection

      include ActiveSupport::Configurable
      include ActiveSupport::Rescuable

      # The purpose of instantiating an schema is to have access to its
      # public methods. It then runs from the strategy perspective, pointing
      # out any other methods to the manually set event
      delegate_missing_to :@event
      attr_reader :event

      self.abstract = true
      self.spec_object = true
      self.directive_location = :schema

      # Imports schema specific configurations
      configure do |config|
        %i[enable_string_collector request_strategies].each do |name|
          config.send("#{name}=", GraphQL.config.send(name))
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
        def kind # :nodoc:
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

        def types(base_class: :Type, &block)
          type_map.each_from(namespace, base_class: base_class, &block)
        end

        # Schemas are assigned to a single namespace
        def set_namespace(*list)
          super(list.first)
        end

        # Schemas are assigned to a single namespace and not inherited
        def namespace(*list)
          list.blank? ? namespaces.first || :base : set_namespace(*list)
        end

        # Check if the class is already registered in the typemap
        def registered?
          type_map.object_exist?(self, exclusive: true)
        end

        # The process to register a class and it's name on the index
        def register!
          return if self == GraphQL::Schema
          return type_map.register(self).method(:validate!) unless registered?

          current = type_map.fetch(:schema,
            namespaces: namespace,
            base_class: :Schema,
            exclusive: true,
          )

          raise ArgumentError, <<~MSG.squish
            The #{namespace.inspect} namespace is already assigned to "#{current.name}".
            Please change the namespace for "#{klass.name}" class.
          MSG
        end

        # Checks if a given method can act as resolver
        def gql_resolver?(method_name)
          (instance_methods - GraphQL::Schema.instance_methods).include?(method_name)
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

          # TODO: Maybe provide an optional 'Any' scalar

          # Generate the helper methods to easily create types within the
          # definition of the schema
          GraphQL::Type::KINDS.each do |kind|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{kind.underscore}(name, **xargs, &block)
                create_type(name, GraphQL::Type.const_get(:#{kind}), **xargs, &block)
              end
            RUBY
          end

          # Rewrite the object method to check if it should use an assigned one
          def object(name_or_object, **xargs, &block)
            return create_type(name_or_object, Type::Object, &block) \
              unless name_or_object.is_a?(Module)

            create_type(name_or_object, Type::Object::AssignedObject, **xargs) do
              self.assigned_to = name_or_object
              class_eval(&block) if block.present?
            end
          end

          # A simpler way to create a new type object without having to create
          # a class in a different file
          def create_type(name, superclass, **xargs, &block)
            xargs[:suffix] = superclass.base_type.name.demodulize
            create_klass(name, superclass, GraphQL::Type, **xargs, &block)
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

              class_eval(&block) if block.present?
              build!
            end
          end

          # Helper method to create multiple sources with the same type
          def sources(*list, of_type: nil, &block)
            list = list.flatten

            of_type ||= GraphQL::Source.find_for!(list.first)
            list.each { |object| source(object, of_type, &block) }
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
              !klass_name.ends_with?(xargs[:suffix])

            if base_module.const_defined?(klass_name)
              klass = base_module.const_get(klass_name)

              raise DuplicatedError, <<~MSG.squish unless !xargs[:once] && klass < superclass
                A constant named "#{klass_name}" already exists for the
                "#{base_module.name}" module.
              MSG
            else
              base_class ||= superclass.ancestors.find { |klass| klass.superclass === Class }

              valid = superclass.is_a?(Module) && superclass < base_class
              raise DefinitionError, <<~MSG.squish unless valid
                The given "#{superclass}" superclass does not inherites from
                #{base_class.name} class.
              MSG

              klass = base_module.const_set(klass_name, Class.new(superclass))
            end

            klass.class_eval(&block) if block.present?
            klass
          end
      end
    end

    ActiveSupport.run_load_hooks(:graphql, Schema)
  end
end
