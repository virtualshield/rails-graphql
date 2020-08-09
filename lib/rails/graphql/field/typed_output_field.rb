# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Shared methods for output fields that contains a specific given type
    module Field::TypedOutputField
      include Helpers::WithArguments
      include Helpers::WithValidator
      include Field::TypedField

      def initialize(*args, method_name: nil, **xargs, &block)
        super(*args, **xargs, &block)

        @method_name = method_name.to_s.underscore.to_sym unless method_name.nil?
      end

      # Check if the field can be resolved from Active Record
      def from_ar?(ar_object)
        result = super
        return result unless result.nil?
        type_klass.from_ar?(ar_object, method_name)
      end

      # Add the attribute name using +method_name+ before calling +from_ar+ on
      # the +type_klass+, then add the alias to the +name+ of the field
      def from_ar(ar_object)
        result = super
        return result unless result.nil?
        type_klass.from_ar(ar_object, method_name)&.as(name)
      end

      # Checks if a given unserialized value is valid for this field
      def valid_output?(value, deep: true)
        return false if disabled?
        return null? if value.nil?
        return valid_output_array?(value, deep) if array?

        return true unless leaf_type? || deep
        type_klass.valid_output?(value)
      end

      # Trigger the exception based value validator
      def validate_output!(value, **xargs)
        raise DisabledFieldError, <<~MSG.squish if disabled?
          The "#{gql_name}" field is disabled.
        MSG

        super(value, :field, **xargs)
      rescue ValidationError => error
        raise InvalidValueError, error.message
      end

      # Checks if the default value of the field is valid
      def validate!(*)
        super if defined? super

        raise ArgumentError, <<~MSG.squish unless type_klass.output_type?
          The "#{type_klass.gql_name}" is not a valid output type.
        MSG

        nil # No exception already means valid
      end

      protected

        def valid_output_array?(value, deep)
          return false unless value.is_a?(Enumerable)

          value.all? do |value|
            (val.nil? && nullable?) || (leaf_type? || !deep) ||
              type_klass.valid_output?(value)
          end
        end
    end
  end
end
