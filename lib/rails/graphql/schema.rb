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
    # This class works similary to the {TypeMap}[rdoc-ref:Rails::GraphQL::TypeMap]
    # class, where its purpose is to know which QueryFields, Mutations, and
    # Subscriptions are available. The main difference is that it doesn't hold
    # namespace-based objects, since each schema is associated to a single
    # namespace.
    class Schema
      extend Helpers::WithSchemaFields
      extend Helpers::WithDirectives
      extend GraphQL::Introspection

      include ActiveSupport::Rescuable
      include GraphQL::Core

      # The namespace associated with the schema
      class_attribute :namespace, instance_writer: false, default: :base

      # The given description of the schema
      class_attribute :description, instance_writer: false

      self.directive_location = :schema

      class << self
        alias namespaces namespace

        # Mark the given class to be pending of registration
        def inherited(subclass)
          super if defined? super
          pending[subclass] ||= caller(1).find do |item|
            !item.end_with?("`inherited'")
          end
        end

        # :singleton-method:
        # Find the schema associated to the given namespace
        def find(namespace)
          organize!
          schemas[namespace.to_sym]
        end

        # Find a given +type+ associated with the schema. It will raise an
        # exception if the +type+ can not be found
        def find_type!(type)
          @@type_map.fetch!(type, namespaces: namespaces)
        end

        # Find a given +directive+ associated with the schema. It will raise an
        # exception if the +directive+ can not be found
        def find_directive!(directive)
          @@type_map.fetch!(directive, base_class: :Directive, namespaces: namespaces)
        end

        # Describe a schema as a GraphQL string
        def to_gql(**xargs)
          ToGQL.describe(self, **xargs)
        end

        private
          # The list of schemas keyd by their corresponding namespace
          def schemas
            @@schemas ||= {}
          end

          # The list pending schames to be registered asscoaited to where they
          # were defined
          def pending
            @@pending ||= {}
          end

          # Organize the pending classes into their specific namespace to easy
          # identification and also ensuring a single schema per namespace
          def organize!
            while (klass, source = pending.shift)
              raise ArgumentError, <<~MSG.squish if schemas.key?(klass.namespace)
                The #{klass.namespace.inspect} namespace is already assigned to
                "#{schemas[klass.namespace].name}". Please change the value for
                "#{klass.name}" class defined at: #{source}
              MSG

              schemas[klass.namespace] = klass
            end
          end
      end
    end

    ActiveSupport.run_load_hooks(:graphql, Schema)
  end
end
