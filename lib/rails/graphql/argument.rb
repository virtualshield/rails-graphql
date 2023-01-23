# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Argument
    #
    # This represents an item from the ArgumentsDefinition, which was supposed
    # to be named InputValue, but for clarification, they work more like
    # function arguments.
    # See http://spec.graphql.org/June2018/#ArgumentsDefinition
    #
    # An argument also works very similar to an ActiveRecord column. For this
    # reason, multi dimensional arrays are not supported. You can define custom
    # input types in order to accomplish something similar to a multi-dimensional
    # array as input.
    #
    # ==== Options
    #
    # * <tt>:owner</tt> - The may object that this argument belongs to.
    # * <tt>:null</tt> - Marks if the overall type can be null
    #   (defaults to true).
    # * <tt>:array</tt> - Marks if the type should be wrapped as an array
    #   (defaults to false).
    # * <tt>:nullable</tt> - Marks if the internal values of an array can be null
    #   (defaults to true).
    # * <tt>:full</tt> - Shortcut for +null: false, nullable: false, array: true+
    #   (defaults to false).
    # * <tt>:default</tt> - Sets a default value for the argument
    #   (defaults to nil).
    # * <tt>:desc</tt> - The description of the argument
    #   (defaults to nil).
    class Argument
      include Helpers::WithValidator
      include Helpers::WithDescription

      # TODO: When arguments are attached to output fields they can have
      # directives so add this possibility

      attr_reader :name, :gql_name, :type, :owner, :default
      attr_accessor :node

      delegate :namespaces, to: :owner

      def initialize(
        name,
        type,
        owner:,
        null: true,
        full: false,
        array: false,
        nullable: true,
        default: nil,
        desc: nil
      )
        @owner = owner
        @name = name.to_s.underscore.to_sym
        @gql_name = @name.to_s.camelize(:lower)

        if type.is_a?(Module) && type < GraphQL::Type
          @type_klass = type
          @type = type.name
        else
          @type = type.to_s.underscore.to_sym
        end

        @null     = full ? false : null
        @array    = full ? true  : array
        @nullable = full ? false : nullable

        @default = default
        @default = deserialize(@default) if @default.is_a?(::GQLParser::Token)
        self.description = desc
      end

      def initialize_copy(*)
        super

        @owner = nil
        @type_klass = nil
      end

      # Check if the other argument is equivalent
      def ==(other)
        other.gql_name == gql_name && self =~ other
      end

      # Check if the other argument is equivalent, regardless the name
      def =~(other)
        return false unless other.is_a?(Argument)
        other.type_klass == type_klass &&
          other.array? == array? &&
          (other.null? == null? || other.null? && !null?) &&
          (other.nullable? == nullable? || other.nullable? && !nullable?)
      end

      # Return the class of the type object
      def type_klass
        @type_klass ||= GraphQL.type_map.fetch!(type,
          namespaces: namespaces,
          prevent_register: owner,
        )
      end

      # Checks if the argument can be null
      def null?
        !!@null
      end

      # Checks if the argument can be an array
      def array?
        !!@array
      end

      # Checks if the argument can have null elements in the array
      def nullable?
        !!@nullable
      end

      # Override to add the kind
      def description(namespace = nil, *)
        super(namespace || owner.try(:namespaces), :argument)
      end

      # Checks if a given default value was provided
      def default_value?
        !@default.nil?
      end

      # Transforms the given value to its representation in a JSON string
      def to_json(value = nil)
        value = @default if value.nil?

        return 'null' if value.nil?
        return type_klass.to_json(value) unless array?
        value.map { |part| type_klass.to_json(part) }
      end

      # Turn the given value into a JSON string representation
      def as_json(value = nil)
        value = @default if value.nil?

        return if value.nil?
        return type_klass.as_json(value) unless array?
        value.map { |part| type_klass.as_json(part) }
      end

      # Turn the given value into a ruby object through deserialization
      def deserialize(value = nil)
        value = as_json if value.nil?

        return if value.nil?
        return type_klass.deserialize(value) unless array?
        value.map { |part| type_klass.deserialize(part) }
      end

      # This checks if a given serialized value is valid for this field
      def valid_input?(value)
        return null? if value.nil?
        return valid_input_array?(value) if array?
        type_klass.valid_input?(value)
      end

      alias valid? valid_input?

      # Trigger the exception based value validator
      def validate_output!(value)
        super(value, :argument)
      end

      # Checks if the definition of the argument is valid
      def validate!(*)
        super if defined? super

        raise NameError, (+<<~MSG).squish if gql_name.start_with?('__')
          The name "#{gql_name}" is invalid. Argument names cannot start with "__".
        MSG

        raise ArgumentError, (+<<~MSG).squish unless type_klass.is_a?(Module)
          Unable to find the "#{type.inspect}" input type on GraphQL context.
        MSG

        raise ArgumentError, (+<<~MSG).squish unless type_klass.input_type?
          The "#{type_klass.gql_name}" is not a valid input type.
        MSG

        raise ArgumentError, (+<<~MSG).squish unless default.nil? || valid?(as_json(default))
          The given default value "#{default.inspect}" is not valid for this argument.
        MSG
      end

      # This allows combining arguments
      def +(other)
        [self, other].flatten
      end

      alias_method :&, :+

      def inspect
        result = +"#{name}: "
        result << '[' if array?
        result << type_klass.gql_name
        result << '!' if array? && !nullable?
        result << ']' if array?
        result << '!' unless null?
        result << " = #{as_json.inspect}" if default_value?
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
