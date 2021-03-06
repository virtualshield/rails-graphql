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

        setup! leaf: true, input: true, output: true

        eager_autoload do
          # Load all the default scalar types
          autoload :IntScalar
          autoload :FloatScalar
          autoload :StringScalar
          autoload :BooleanScalar
          autoload :IdScalar

          # Load all additional scalar types
          autoload :BigintScalar
          autoload :BinaryScalar
          autoload :DateScalar
          autoload :DateTimeScalar
          autoload :DecimalScalar
          autoload :JsonScalar
          autoload :TimeScalar
        end

        class << self
          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value.is_a?(String)
          end

          # Check if a given value is a valid non-serialized output
          def valid_output?(value)
            value.respond_to?(:to_s)
          end

          # Transforms the given value to its representation in a JSON string
          def to_json(value)
            as_json(value)&.inspect
          end

          # Transforms the given value to its representation in a Hash object
          def as_json(value)
            value.to_s
          end

          # Turn a user input of this given type into an ruby object
          def deserialize(value)
            value
          end

          def inspect # :nodoc:
            "#<GraphQL::Scalar #{gql_name}>"
          end
        end
      end
    end
  end
end
