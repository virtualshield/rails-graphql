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
      redefine_singleton_method(:input_type?) { true }
      self.directive_location = :input_field_definition

      attr_reader :type, :default, :directives

      def initialize(
        name,
        type,
        *args,
        default: nil,
        directives: nil,
        **xargs,
        &block
      )
        super(name, **xargs, &block)

        @type = GraphQL.find_input_type(type) || type
        assign_directives(directives)

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

      # Checks if a given default value was provided
      def default_value?
        !@default.nil?
      end

      # Turn the default value into a JSON string representation
      def default_to_json
        to_json(@default)
      end

      # This checks if a given serialized value is valid for this field
      def valid_input?(value)
        return null? if value.nil?
        return valid_input_array?(value) if array?
        type.valid_input?(value)
      end

      # Turn the given value into a JSON string representation
      def to_json(value)
        return nil if value.nil?
        return type.to_json(value) unless array?

        entries = value.map { |part| type.to_json(part) }
        "[#{entries.join(', ')}]"
      end

      # Checks if the definition of the field is valid. Doens't check for
      # arguments because input fields doesn't accepts arguments
      def validate!(valid_types = [])
        raise ArgumentError, <<~MSG.squish unless type.is_a?(Module)
          Unable to find the "#{type.inspect}" input type on GraphQL context.
        MSG

        valid_type = type.try(:input_type?) && type < GraphQL::Type
        raise ArgumentError, <<~MSG.squish unless valid_type
          The "#{type.gql_name}" is not a valid input type.
        MSG

        valid_type = valid_types.empty? || (valid_types.any? { |base_type| type < base_type })
        raise ArgumentError, <<~MSG.squish unless valid_type
          The "#{type.base_type}" is not accepted in this context.
        MSG

        raise ArgumentError, <<~MSG.squish unless default.nil? || valid?(default)
          The given default value "#{default.inspect}" is not valid for this field.
        MSG
      end

      protected

        def valid_input_array?(value)
          return false unless value.is_a?(Enumerable)
          value.all? { |val| (val.nil? && nullable?) || type.valid_input?(val) }
        end
    end
  end
end
