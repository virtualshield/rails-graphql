# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Mutation
    #
    # This is the base class for mutations definition.
    # See: http://spec.graphql.org/June2018/#sec-Mutation
    class Mutation
      extend Helpers::WithDirectives
      extend Helpers::WithNamespace
      extend Helpers::WithArguments
      extend Helpers::Registerable

      class << self
        delegate :valid_output?, :leaf_type?, :to_json, :to_hash, to: :type_klass

        attr_reader :type

        def gql_name # :nodoc:
          return @gql_name if defined?(@gql_name)
          @gql_name = super.camelize(:lower)
        end

        # Configure the return type of the mutation
        #
        # ==== Options
        #
        # * <tt>:null</tt> - Marks if the return type can be null
        #   (defaults to false).
        # * <tt>:array</tt> - Marks if the type should be wrapped as an array
        #   (defaults to false).
        # * <tt>:nullable</tt> - Marks if the internal values of an array can be null
        #   (defaults to false).
        def returns(type, null: false, array: false, nullable: false)
          @type = type.to_s.underscore.to_sym

          @null     = null
          @array    = array
          @nullable = nullable
        end

        # Return the class of the type object
        def type_klass
          @type_klass ||= GraphQL.type_map.fetch!(type, namespaces: namespaces)
        end

        # Checks if the argument can be null
        def null?
          @null
        end

        # Checks if the argument can be an array
        def array?
          @array
        end

        # Checks if the argument can have null elements in the array
        def nullable?
          @nullable
        end

        # Check if the object definition is valid
        def validate!(*)
          super if defined? super

          raise ArgumentError, <<~MSG.squish if type.nil?
            You must configure the return type of the mutation using "returns".
          MSG

          raise ArgumentError, <<~MSG.squish unless public_instance_methods.include?(:perform)
            The "#{gql_name}" mutation doesn't have a public method "perform".
          MSG

          raise ArgumentError, <<~MSG.squish unless type_klass.is_a?(Module)
            Unable to find the "#{type.inspect}" input type on GraphQL context.
          MSG

          raise ArgumentError, <<~MSG.squish unless type_klass.input_type?
            The "#{type_klass.gql_name}" is not a valid input type.
          MSG

          nil # No exception already means valid
        end
      end
    end
  end
end
