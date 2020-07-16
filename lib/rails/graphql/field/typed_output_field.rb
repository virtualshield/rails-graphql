# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Shared methods for output fields that contains a specific given type
    module Field::TypedOutputField
      include Helpers::WithArguments
      include Field::TypedField

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

      # This checks if a given unserialized value is valid for this field
      def valid_output?(value)
        return false if disabled?
        return null? if value.nil?
        return valid_output_array?(value) if array?
        type_klass.valid_output?(value)
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

        def valid_output_array?(value)
          return false unless value.is_a?(Enumerable)
          value.all? { |val| (val.nil? && nullable?) || type_klass.valid_output?(val) }
        end
    end
  end
end
