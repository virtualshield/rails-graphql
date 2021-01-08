# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Output Field
    #
    # Most of the fields in a GraphQL operation are output fields or similar or
    # proxies of it. They can express both leaf and branch data. They can also
    # be the entry point of a GraphQL request.
    class Field::OutputField < Field
      include Helpers::WithArguments
      include Helpers::WithValidator
      include Helpers::WithEvents
      include Helpers::WithCallbacks

      include Field::AuthorizedField
      include Field::ResolvedField
      include Field::TypedField

      module Proxied # :nodoc: all
        def initialize(*args, **xargs, &block)
          @method_name = xargs.delete(:method_name) if xargs.key?(:method_name)
          super(*args, **xargs, &block)
        end

        def all_arguments
          field.arguments.merge(super)
        end

        def has_argument?(name)
          super || field.has_argument?(name)
        end
      end

      redefine_singleton_method(:output_type?) { true }
      self.directive_location = :field_definition

      def initialize(*args, method_name: nil, deprecated: false, **xargs, &block)
        @method_name = method_name.to_s.underscore.to_sym unless method_name.nil?

        if deprecated.present?
          xargs[:directives] = Array.wrap(xargs[:directives])
          xargs[:directives] << Directive::DeprecatedDirective.new(
            reason: (deprecated.is_a?(String) ? deprecated : nil),
          )
        end

        super(*args, **xargs, &block)
      end

      # Check if the arguments are also equivalent
      def =~(other)
        super && match_arguments?(other)
      end

      # Checks if a given unserialized value is valid for this field
      def valid_output?(value, deep: true)
        return false unless super
        return null? if value.nil?
        return valid_output_array?(value, deep) if array?

        return true unless leaf_type? || deep
        type_klass.valid_output?(value)
      end

      # Trigger the exception based value validator
      def validate_output!(value, **xargs)
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
      end

      protected

        # Check if the given +value+ is a valid array as output
        def valid_output_array?(value, deep)
          return false unless value.is_a?(Enumerable)

          value.all? do |val|
            (val.nil? && nullable?) || (leaf_type? || !deep) ||
              type_klass.valid_output?(val)
          end
        end

        def proxied # :nodoc:
          super if defined? super
          extend Field::OutputField::Proxied
        end
    end
  end
end
