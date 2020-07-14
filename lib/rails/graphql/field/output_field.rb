# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Field::OutputField < Field
      include Field::TypedOutputField
      include Field::ResolvedField

      redefine_singleton_method(:output_type?) { true }
      self.directive_location = :field_definition

      def initialize(*args, deprecated: false, **xargs, &block)
        if deprecated.present?
          xargs[:directives] = Array.wrap(xargs[:directives])
          xargs[:directives] << Directive::DeprecatedDirective.new(
            reason: (deprecated.is_a?(String) ? deprecated : nil)
          )
        end

        super(*args, **xargs, &block)
      end
    end
  end
end
