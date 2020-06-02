# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Input Field
    #
    # An input field works the same way as an argument, and they are pretty much
    # equivalent. The main difference bvetween an argument and a field input is
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

      # Override with exception
      def configure
        raise ArgumentError, 'Input fields can\'t be furthere configured using blocks'
      end

      # Override with exception
      def argument(*)
        raise ArgumentError, 'Input fields doesn\'t support arguments'
      end

      # Checks if a default value was provided
      def default_value?
        !default.nil?
      end

      # Turn the default value into a JSON string representation
      def default_to_json
        to_json(default)
      end

      # This checks if a given serialized value is valid for this field
      def valid_input?(value)
        return null? if value.nil?
        return valid_input_array?(value) if array?
        type_klass.valid_input?(value)
      end

      # Turn the given value into an ruby representation of it
      def deserialize(value)
        value.nil? ? default : super
      end

      # Checks if the default value of the field is valid
      def validate!
        super if defined? super

        raise ArgumentError, <<~MSG.squish unless default.nil? || valid?(default)
          The given default value "#{default.inspect}" is not valid for this field.
        MSG
      end

      def inspect # :nodoc:
        result = super
        result += " = #{default_to_json}" if default?
        result
      end

      protected

        def valid_input_array?(value)
          return false unless value.is_a?(Array)
          value.all? { |val| (val.nil? && nullable?) || type_klass.valid_input?(val) }
        end
    end
  end
end
