# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Field::OutputField < Field
      include Field::TypedField

      redefine_singleton_method(:output_type?) { true }
      self.directive_location = :field_definition

      def initialize(*args, deprecated: false, **xargs, &block)
        if !!deprecated
          xargs[:directives] = xargs[:directives].to_a
          xargs[:directives] << Directive::DeprecatedDirective.new(
            reason: (deprecated.is_a?(String) ? deprecated : nil)
          )
        end

        super(*args, **xargs, &block)
      end

      # This checks if a given unserialized value is valid for this field
      def valid_output?(value)
        return null? if value.nil?
        return valid_output_array?(value) if array?
        type_klass.valid_output?(value)
      end

      protected

        def valid_output_array?(value)
          return false unless value.is_a?(Enumerable)
          value.all? { |val| (val.nil? && nullable?) || type_klass.valid_output?(val) }
        end
    end
  end
end
