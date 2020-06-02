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
    # * <tt>:desc</tt> - The description of the argument (defaults to nil).
    #
    # It also accepts a block for furthere configurations
    class Field
      include Helpers::WithDirectives
      include Helpers::WithArguments

      attr_reader :name, :gql_name, :owner

      delegate :input_type?, :output_type?, :leaf_type?, to: :class
      delegate :namespaces, to: :owner
      delegate :[], to: :arguments

      # Load all the subtype of fields
      require_relative 'field/typed_field'

      require_relative 'field/input_field'
      require_relative 'field/output_field'

      class ScopedConfig < Struct.new(:field) # :nodoc: all
        delegate :argument, :use, to: :field

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
      end

      def initialize(
        name,
        owner: ,
        null: true,
        array: false,
        nullable: true,
        directives: nil,
        desc: nil,
        &block
      )
        @owner = owner
        @name = name.to_s.underscore.to_sym
        @gql_name = @name.to_s.camelize(:lower)
        @directives = GraphQL.directives_to_set(directives, [], directive_location)

        @null = null
        @array = array
        @nullable = nullable
        @desc = desc&.squish

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

      # This method must be overridden by children classes
      def valid_input?(*)
        false
      end

      # This method must be overridden by children classes
      def valid_output?(*)
        false
      end

      # Check if the given value is valid using +valid_input?+ or
      # +valid_output?+ depending of the type of the field
      def valid?(value)
        input_type? ? valid_input?(value) : valid_output?(value)
      end

      # Checks if the definition of the field is valid.
      def validate!
        super if defined? super
      end

      def inspect # :nodoc:
        "#{name}: "
      end
    end
  end
end
