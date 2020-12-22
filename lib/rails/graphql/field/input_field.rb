# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Input Field
    #
    # An input field works the same way as an argument and they are pretty much
    # equivalent. The main difference between an argument and a input field is
    # that input fields holds object-like values and they can be inherited.
    # Arguments can hold object-like values only when their type is associated
    # with an InputField.
    #
    # ==== Options
    #
    # * <tt>:default</tt> - Sets a default value for the argument (defaults to nil).
    # * <tt>:directives</tt> - The list of directives associated with the value
    #   (defaults to nil).
    class Field::InputField < Field
      include Field::TypedField

      attr_reader :default

      redefine_singleton_method(:input_type?) { true }
      self.directive_location = :input_field_definition

      def initialize(*args, default: nil, **xargs, &block)
        super(*args, **xargs, &block)
        @default = default
      end

      def configure # :nodoc:
        raise ArgumentError, 'Input fields can\'t be further configured using blocks'
      end

      # Allow change the default value for the input
      def apply_changes(**xargs, &block)
        @default = xargs[:default] if xargs.key?(:default)
        super
      end

      # Checks if a default value was provided
      def default_value?
        !default.nil?
      end

      # This checks if a given serialized value is valid for this field
      def valid_input?(value, deep: true)
        return false unless super
        return null? if value.nil?
        return valid_input_array?(value, deep) if array?

        return true unless leaf_type? || deep
        type_klass.valid_input?(value)
      end

      # Return the default value if the given +value+ is nil
      def deserialize(value = nil)
        value.nil? ? default : super
      end

      # A little override to use the default value
      def to_json(value = nil)
        super(value.nil? ? default : value)
      end

      # A little override to use the default value
      def as_json(value = nil)
        super(value.nil? ? default : value)
      end

      # Checks if the default value of the field is valid
      def validate!(*)
        super if defined? super

        raise ArgumentError, <<~MSG.squish unless type_klass.input_type?
          The "#{type_klass.gql_name}" is not a valid input type.
        MSG

        raise ArgumentError, <<~MSG.squish unless default.nil? || valid_input?(default)
          The given default value "#{default.inspect}" is not valid for this field.
        MSG
      end

      protected

        # Check if the given +value+ is a valid array as input
        def valid_input_array?(value, deep)
          return false unless value.is_a?(Array)

          value.all? do |val|
            (val.nil? && nullable?) || (leaf_type? || !deep) ||
              type_klass.valid_input?(val)
          end
        end

        # Display the default value when it is present for inspection
        def inspect_default_value
          " = #{to_hash.inspect}" if default?
        end
    end
  end
end
