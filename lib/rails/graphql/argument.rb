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
    # * <tt>:full</tt> - Shortcut for +null: false, nullable: false, array: true+
    #   (defaults to false).
    # * <tt>:directives</tt> - The list of directives associated with the value
    #   (defaults to nil).
    # * <tt>:default</tt> - Sets a default value for the argument (defaults to nil).
    # * <tt>:desc</tt> - The description of the argument (defaults to nil).
    class Argument
      attr_reader :name, :gql_name, :type, :owner, :default, :directives

      delegate :namespaces, to: :owner

      def initialize(
        name,
        type,
        owner: ,
        null: true,
        full: false,
        array: false,
        nullable: true,
        default: nil,
        desc: nil,
        directives: nil
      )
        @owner = owner
        @name = name.to_s.underscore.to_sym
        @type = type.to_s.underscore.to_sym
        @gql_name = @name.to_s.camelize(:lower)

        @directives = GraphQL.directives_to_set(directives, [], :argument_definition)

        @null     = full ? false : null
        @array    = full ? true  : array
        @nullable = full ? false : nullable

        @default = default
        @desc = desc&.squish
      end

      def initialize_copy(*)
        super

        @owner = nil
        @type_klass = nil
      end

      # Check if the other argument is equivalent
      def ==(other)
        other.gql_name == gql_name &&
          other.null? == null? &&
          other.array? == array? &&
          other.nullable? == nullable?
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
      def default_to_hash
        to_hash(@default)
      end

      # Transforms the given value to its representation in a JSON string
      def to_json(value)
        to_hash(value).inspect
      end

      # Turn the given value into a JSON string representation
      def to_hash(value)
        return @default if value.nil?
        return type_klass.to_hash(value) unless array?
        value.map { |part| type_klass.to_hash(part) }
      end

      # This checks if a given serialized value is valid for this field
      def valid_input?(value)
        return null? if value.nil?
        return valid_input_array?(value) if array?
        type_klass.valid_input?(value)
      end

      alias valid? valid_input?

      # Checks if the definition of the argument is valid
      def validate!(*)
        super if defined? super

        raise NameError, <<~MSG.squish if gql_name.start_with?('__')
          The name "#{gql_name}" is invalid. Arugments name cannot start with "__".
        MSG

        raise ArgumentError, <<~MSG.squish unless type_klass.is_a?(Module)
          Unable to find the "#{type.inspect}" input type on GraphQL context.
        MSG

        raise ArgumentError, <<~MSG.squish unless type_klass.input_type?
          The "#{type_klass.gql_name}" is not a valid input type.
        MSG

        raise ArgumentError, <<~MSG.squish unless default.nil? || valid?(default)
          The given default value "#{default.inspect}" is not valid for this argument.
        MSG

        nil # No exception already means valid
      end

      # This allows combining arguments
      def +(other)
        [self, other].flatten
      end

      alias_method :&, :+

      def inspect # :nodoc:
        result = "#{name}: "
        result += '[' if array?
        result += type_klass.gql_name
        result += '!' if array? && !nullable?
        result += ']' if array?
        result += '!' unless null?
        result
      end

      private

        def valid_input_array?(value)
          return false unless value.is_a?(Enumerable)
          value.all? { |val| (val.nil? && nullable?) || type_klass.valid_input?(val) }
        end
    end
  end
end
