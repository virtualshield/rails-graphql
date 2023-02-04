# frozen_string_literal: true

require 'globalid'

module Rails
  module GraphQL
    # = GraphQL Global ID
    #
    # GraphQL implementation of the Global ID that adds extended support to how
    # things are located and stored. Mostly used for caching and custom access
    # to the tree and request process.
    #
    # TODO: Implement signed operations
    class GlobalID < ::GlobalID
      SERIALIZER_KEY = "_gql_globalid"

      # This adds support to ActiveJob serialization, which can be used to pass
      # GraphQL objects to jobs and also deserialize things for subscriptions
      class Serializer
        include Singleton

        class << self
          delegate :serialize?, :serialize, :deserialize, to: :instance
        end

        # Determines if an argument should be serialized by this serializer.
        def serialize?(argument)
          argument.is_a?(Helpers::WithGlobalID) || argument.class.is_a?(Helpers::WithGlobalID)
        end

        # Serializes an argument to a JSON primitive type.
        def serialize(argument)
          { GlobalID::SERIALIZER_KEY => argument.to_global_id.to_s }
        end

        # Deserializes an argument from a JSON primitive type.
        def deserialize(argument)
          GlobalID.find argument[GlobalID::SERIALIZER_KEY]
        end

        private
          # The class of the object that will be serialized.
          def klass
            GlobalID
          end
      end

      class << self
        undef_method :app, :app=

        # Create a new GraphQL Global identifier
        def create(object, options = nil)
          scope = options&.delete(:scope) || scope_of(object)
          new(URI::GQL.create(object, scope, options), options)
        end

        # Find the scope on which the object is applied to
        def scope_of(object)
          object.try(:schema_type) if object.gid_base_class.is_a?(Helpers::WithSchemaFields)
        end
      end

      undef_method :app, :model_name, :model_id
      delegate :namespace, :class_name, :scope, :name, :instantiate?, to: :uri

      def initialize(gid, options = {})
        @uri = gid.is_a?(URI::GQL) ? gid : URI::GQL.parse(gid)
      end

      def find(options = {})
        base_class.try(:find_by_gid, self)
      end

      def base_class
        if %w[Schema Directive Type].include?(class_name)
          GraphQL.const_get(class_name, false)
        else
          GraphQL.type_map.fetch(class_name, namespace: namespace)
        end
      end

      def ==(other)
        other.is_a?(GlobalID) && @uri == other.uri
      end

      alias eql? ==
    end
  end
end
