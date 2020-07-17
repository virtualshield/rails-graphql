# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This is a helper module that basically works with fields that have an
    # assigned type value
    module Field::TypedField
      attr_reader :type

      delegate :input_type?, :output_type?, :leaf_type?, :kind, to: :type_klass
      delegate :valid_field_types, to: :owner

      def initialize(name, type, *args, **xargs, &block)
        super(name, *args, **xargs, &block)

        if type.is_a?(Module) && type < GraphQL::Type
          @type_klass = type
          @type = type.name
        else
          @type = type.to_s.underscore.to_sym
        end
      end

      def initialize_copy(*)
        super

        @type_klass = nil
      end

      # Check if types are compatible
      def ==(other)
        other.type_klass == type_klass && super
      end

      # Return the class of the type object
      def type_klass
        @type_klass ||= GraphQL.type_map.fetch!(type, namespaces: namespaces)
      end

      # Checks if the type of the field is valid
      def validate!(*)
        super if defined? super

        raise ArgumentError, <<~MSG.squish unless type_klass.is_a?(Module)
          Unable to find the "#{type.inspect}" input type on GraphQL context.
        MSG

        valid_type = valid_field_types.empty? || valid_field_types.any? do |base_type|
          type_klass < base_type
        end

        raise ArgumentError, <<~MSG.squish unless valid_type
          The "#{type_klass.base_type}" is not accepted in this context.
        MSG

        nil # No exception already means valid
      end

      protected

        def inspect_type # :nodoc:
          result = ' '
          result += '[' if array?
          result += type_klass.gql_name
          result += '!' if array? && !nullable?
          result += ']' if array?
          result += '!' unless null?
          result
        end
    end
  end
end
