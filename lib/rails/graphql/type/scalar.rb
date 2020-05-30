# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL ScalarType
      #
      # Scalar types represent primitive leaf values in a GraphQL type system.
      # See http://spec.graphql.org/June2018/#ScalarTypeDefinition
      #
      # This class works very similarly to ActiveModel::Type::Value, but instead
      # of working with instances, we operate in the singleton way.
      #
      # The +ar_type+ defines to which ActiveRecord type the value is casted
      # when serializing to hash, which indicates if a cast is necessary or not.
      class Scalar < Type
        extend ActiveSupport::Autoload

        redefine_singleton_method(:leaf_type?) { true }
        redefine_singleton_method(:scalar?) { true }
        define_singleton_method(:kind) { :scalar }
        self.directive_location = :scalar
        self.abstract = true

        ##
        # Load all the default scalar types
        autoload :IntScalar
        autoload :FloatScalar
        autoload :StringScalar
        autoload :BooleanScalar
        autoload :IdScalar

        ##
        # Load all additional scalar types
        autoload :BigintScalar
        autoload :BinaryScalar
        autoload :DateScalar
        autoload :DateTimeScalar
        autoload :DecimalScalar
        autoload :TimeScalar

        # Marks if the scalar object is one of those defined on the spec
        class_attribute :spec_scalar, instance_writer: false, default: false

        # Defines which type exactly represents the scalar type on the
        # ActiveRecord adapter for casting purposes
        class_attribute :ar_adapter_type, instance_writer: false, default: {}

        # A list of ActiveRecord aliases per adapter for non-casting operations
        class_attribute :ar_adapter_aliases, instance_writer: false,
          default: Hash.new { |h, k| h[k] = [] }

        class << self
          # Reset some class attributes, meaning that they are not cascade
          def inherited(subclass)
            subclass.spec_scalar = false
            super
          end

          # Check if a given deserialized value is valid
          def valid?(value)
            value.respond_to?(:to_s)
          end

          # Transforms the given value to its representation in a JSON string
          def to_json(value)
            to_hash(value).inspect
          end

          # Transforms the given valye to its representation in a Hash object
          def to_hash(value)
            value.to_s
          end

          # Turn a user input of this given type into an ruby object
          def deserialize(value)
            to_hash(value)
          end

          # Returns an areal object that represents how this object is
          # serialized direct from the query
          def from_ar(ar_object, attribute)
            key = adapter_key(ar_object)
            method_name = "from_#{key}_adapter"
            method_name = 'from_abstract_adapter' unless respond_to?(method_name, true)
            arel_object = send(method_name, ar_object, attribute)

            return arel_object if match_ar_type?(ar_object, attribute, key)
            send("cast_#{key}_attribute", arel_object, ar_adapter_type[key])
          end

          protected

            # A pretty abstract way to access an attribute from an ActiveRecord
            # object using arel
            def from_abstract_adapter(ar_object, attribute)
              ar_object.arel_attribute(attribute)
            end

          private

            # Given the ActiveRecord Object, find the key to compund the method
            # name for the specific attribute accessor
            def adapter_key(ar_object)
              GraphQL::Schema.ar_adapters[ar_object.connection.adapter_name]
            end

            # Check if the GraphQL ar type of this object matches the
            # ActiveRecord type or any alias for the specific adapter
            def match_ar_type?(ar_object, attribute, adapter_key)
              attr_type = ar_object.columns_hash[attribute.to_s].type
              ar_type.eql?(attr_type) || ar_adapter_aliases[adapter_key].include?(attr_type)
            end
        end
      end
    end
  end
end
