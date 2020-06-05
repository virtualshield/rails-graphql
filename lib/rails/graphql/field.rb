# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Field
    #
    # A field has multiple purposes, which is defined by the specific subclass
    # used. They are also, in various ways, similar to arguments, since they
    # tend to have the same strcuture.
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
    # * <tt>:desc</tt> - The description of the argument (defaults to nil).
    #
    # It also accepts a block for furthere configurations
    class Field
      include Helpers::WithDirectives
      include Helpers::WithArguments

      attr_reader :name, :gql_name, :owner

      delegate :input_type?, :output_type?, :leaf_type?, :from_ar?, :from_ar, to: :class
      delegate :namespaces, to: :owner
      delegate :[], to: :arguments

      # Load all the subtype of fields
      require_relative 'field/typed_field'

      require_relative 'field/input_field'
      require_relative 'field/output_field'

      class ScopedConfig < Struct.new(:field) # :nodoc: all
        delegate :argument, :use, :internal!, to: :field

        def desc(value)
          field.instance_variable_set(:@desc, value.squish)
        end
      end

      class << self
        # Defines if the current field is valid as an input type
        def input_type?
          false
        end

        # Defines if the current field is valid as an output type
        def output_type?
          false
        end

        # Defines if the current field is considered a leaf output
        def leaf_type?
          false
        end

        # Normally extended fields cannot be serialized during a query. But, by
        # having this and the +from_ar+ methods, other classes can override them
        # and provide a valid fetcher.
        def from_ar?(*)
          false
        end

        # Just to ensure the compatibility with other outputs.
        def from_ar(*)
        end
      end

      def initialize(
        name,
        owner: ,
        null: true,
        full: false,
        array: false,
        nullable: true,
        directives: nil,
        desc: nil,
        **xargs,
        &block
      )
        @owner = owner
        @name = name.to_s.underscore.to_sym
        @gql_name = @name.to_s.camelize(:lower)
        @directives = GraphQL.directives_to_set(directives, [], directive_location)

        @null     = full ? false : null
        @array    = full ? true  : array
        @nullable = full ? false : nullable

        @desc = desc&.squish

        super(**xargs) if defined? super
        configure(&block) if block.present?
      end

      def initialize_copy(*)
        super

        @owner = nil
      end

      # Allow extra configurations to be performed using a block
      def configure(&block)
        ScopedConfig.new(self).instance_exec(&block)
      end

      # Check if the other field is equivalent
      def ==(other)
        other.gql_name == gql_name &&
          (other.null? == null? || other.null? && !null?) &&
          other.array? == array? &&
          other.nullable? == nullable? &&
          match_arguments?(other)
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

      # Check if the field is an internal one
      def internal?
        @internal
      end

      # Mark the field as an internal one, which comes from the spec and then
      # can contain a name starting with "__"
      def internal!
        @internal = true
      end

      # This method must be overridden by children classes
      def valid_input?(*)
        false
      end

      # This method must be overridden by children classes
      def valid_output?(*)
        false
      end

      # Transforms the given value to its representation in a JSON string
      def to_json(value)
        to_hash(value).inspect
      end

      # Turn the given value into a JSON string representation
      def to_hash(value)
        return nil if value.nil?
        return type_klass.to_hash(value) unless array?
        value.map { |part| type_klass.to_hash(part) }
      end

      # Turn a user input of this given type into an ruby object
      def deserialize(value)
        return if value.nil?
        return type_klass.deserialize(value) unless array?
        value.map { |val| type_klass.deserialize(val) unless val.nil? }
      end

      # Check if the given value is valid using +valid_input?+ or
      # +valid_output?+ depending of the type of the field
      def valid?(value)
        input_type? ? valid_input?(value) : valid_output?(value)
      end

      # Checks if the definition of the field is valid.
      def validate!(*)
        super if defined? super

        raise NameError, <<~MSG.squish if !internal? && gql_name.start_with?('__')
          The name "#{gql_name}" is invalid. Only internal fields from the
          spec can have a name starting with "__".
        MSG

        nil # No exception already means valid
      end

      def inspect # :nodoc:
        args = arguments.each_value.map(&:inspect)
        args = args.presence && "(#{args.join(', ')})"
        "#{name}#{args}: "
      end

      private

        def match_arguments?(other)
          other.arguments.size == arguments.size &&
            other.arguments.all? { |key, arg| arg == arguments[key] }
        end
    end
  end
end
