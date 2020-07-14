# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Field
    #
    # A field has multiple purposes, which is defined by the specific subclass
    # used. They are also, in various ways, similar to arguments, since they
    # tend to have the same structure.
    # array as input.
    #
    # ==== Options
    #
    # * <tt>:owner</tt> - The may object that this field belongs to.
    # * <tt>:null</tt> - Marks if the overall type can be null
    #   (defaults to true).
    # * <tt>:array</tt> - Marks if the type should be wrapped as an array
    #   (defaults to false).
    # * <tt>:nullable</tt> - Marks if the internal values of an array can be null
    #   (defaults to true).
    # * <tt>:full</tt> - Shortcut for +null: false, nullable: false, array: true+
    #   (defaults to false).
    # * <tt>:method_name</tt> - The name of the method used to fetch the field data
    #   (defaults to nil).
    # * <tt>:directives</tt> - The list of directives associated with the value
    #   (defaults to nil).
    # * <tt>:desc</tt> - The description of the argument
    #   (defaults to nil).
    #
    # It also accepts a block for further configurations
    class Field
      include Helpers::WithDirectives
      include Helpers::WithArguments

      class ScopedConfig < Struct.new(:field, :receiver) # :nodoc: all
        delegate :argument, :id_argument, :use, :internal!, to: :field
        delegate_missing_to :receiver

        def desc(value)
          field.instance_variable_set(:@desc, value.strip_heredoc.chomp)
        end
      end

      attr_reader :name, :gql_name, :owner, :directives

      delegate :input_type?, :output_type?, :leaf_type?, :from_ar?, :from_ar, to: :class
      delegate :namespaces, to: :owner
      delegate :[], to: :arguments

      # Load all the subtype of fields
      require_relative 'field/resolved_field'
      require_relative 'field/typed_field'

      require_relative 'field/input_field'
      require_relative 'field/output_field'

      class << self
        # Normally extended fields cannot be serialized during a query. But, by
        # having this and the +from_ar+ methods, other classes can override them
        # and provide a valid fetcher.
        def from_ar?(*)
        end

        # Just to ensure the compatibility with other outputs.
        def from_ar(*)
        end

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
        full: false,
        array: false,
        nullable: true,
        directives: nil,
        method_name: nil,
        desc: nil,
        **xargs,
        &block
      )
        @owner = owner
        @name = name.to_s.underscore.to_sym
        @directives = GraphQL.directives_to_set(directives, source: self)
        @method_name = method_name.to_s.underscore.to_sym unless method_name.nil?

        @gql_name = @name.to_s.camelize(:lower)
        @gql_name = "__#{@gql_name.camelize(:lower)}" if internal?

        @null     = full ? false : null
        @array    = full ? true  : array
        @nullable = full ? false : nullable

        @desc = desc&.strip_heredoc&.chomp

        super(**xargs) if defined? super
        configure(&block) if block.present?
      end

      def initialize_copy(*)
        super

        @owner = nil
      end

      # Allow extra configurations to be performed using a block
      def configure(&block)
        ScopedConfig.new(self, block.binding.receiver).instance_exec(&block)
      end

      # Returns the name of the method used to retrieve the information
      def method_name
        defined?(@method_name) ? @method_name : @name
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
        name.start_with?('__')
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

      def inspect(extra = '') # :nodoc:
        dirs = directives.map(&:inspect)
        dirs = dirs.presence && " #{dirs.join(' ')}"

        args = arguments.each_value.map(&:inspect)
        args = args.presence && "(#{args.join(', ')})"
        "#<GraphQL::Field @owner=\"#{owner.name}\" #{name}#{args}:#{extra}#{dirs}>"
      end

      # Update the null value
      def required!
        @null = false
      end

      private

        def match_arguments?(other)
          other.arguments.size == arguments.size &&
            other.arguments.all? { |key, arg| arg == arguments[key] }
        end
    end
  end
end
