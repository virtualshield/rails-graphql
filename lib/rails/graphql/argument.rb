# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Argument
    #
    # This represents an item from the ArgumentsDefinition, which was supposed
    # to be named InputValue, but for clarification, they work more like
    # function arguments.
    # See http://spec.graphql.org/June2018/#ArgumentsDefinition
    #
    # An aargument also works very similary as an ActiveRecord column. For this
    # reason, multi dimensional arrays are not supported. You can define custom
    # input types in order to accomplish something similar to a multi-demnsional
    # array as input.
    #
    # ==== Options
    #
    # * <tt>:null</tt> - Marks if the overal type can be nuull (defaults to true).
    # * <tt>:array</tt> - Marks if the type should be wrapped as an array (defaults to false).
    # * <tt>:nullable</tt> - Marks if the internal values of an array can be null
    #   (defaults to true).
    # * <tt>:directives</tt> - The list of directives associated with the value
    #   (defaults to nil).
    # * <tt>:default</tt> - Sets a default value for the argument (defaults to nil).
    # * <tt>:desc</tt> - The description of the argument (defaults to nil).
    class Argument
      attr_reader :name, :gql_name, :type, :default, :directives

      def initialize(
        name,
        type,
        null: true,
        array: false,
        nullable: true,
        default: nil,
        desc: nil,
        directives: nil
      )
        @name = name.to_s.underscore.to_sym
        @gql_name = @name.to_s.camelize(:lower)
        @type = GraphQL.find_input_type(type) || type

        @directives = GraphQL.directives_to_set(directives, [], :argument_definition)

        @null = null
        @array = array
        @nullable = nullable
        @default = default
        @desc = desc&.squish
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

      # Return the description of the argument
      def description
        @desc
      end

      # Checks if a description was provided
      def description?
        !!@desc
      end

      # Checks if a given default value was provided
      def default_value?
        !@default.nil?
      end

      # Turn the default value into a JSON string representation
      def default_to_json
        to_json(@default)
      end

      # Turn the given value into a JSON string representation
      def to_json(value)
        return nil if value.nil?
        return type.to_json(value) unless array?

        entries = value.map { |part| type.to_json(part) }
        "[#{entries.join(', ')}]"
      end

      # This checks if a given serialized value is valid for this argument
      def valid?(value)
        return null? if value.nil?
        return valid_array?(value) if array?
        type.valid_input?(value)
      end

      # Checks if the definition of the argument is valid
      def validate!
        raise ArgumentError, <<~MSG.squish unless type.is_a?(Module)
          Unable to find the "#{type.inspect}" input type on GraphQL context.
        MSG

        valid_type = type.try(:input_type?) && type < GraphQL::Type
        raise ArgumentError, <<~MSG.squish unless valid_type
          The "#{type.gql_name}" is not a valid input type.
        MSG

        raise ArgumentError, <<~MSG.squish unless default.nil? || valid?(default)
          The given default value "#{default.inspect}" is not valid for this argument.
        MSG
      end

      private

        def valid_array?(value)
          return false unless value.is_a?(Enumerable)
          value.all? { |val| (val.nil? && nullable?) || type.valid_input?(val) }
        end
    end
  end
end
