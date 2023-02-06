# frozen_string_literal: true

module Rails
  module GraphQL
    # This is a helper module that basically works with fields that have an
    # assigned type value
    module Field::TypedField
      module Proxied # :nodoc: all
        delegate :type, to: :field
      end

      attr_reader :type

      delegate :input_type?, :output_type?, :leaf_type?, :kind, to: :type_klass

      def initialize(name, type = nil, *args, **xargs, &block)
        type = (name == :id ? :id : :string) if type.nil?
        assign_type(type)
        super(name, *args, **xargs, &block)
      end

      def initialize_copy(*)
        super

        @type_klass = nil
      end

      # Check if types are compatible
      def =~(other)
        super && other.is_a?(Field::TypedField) && other.type_klass =~ type_klass
      end

      # Sometimes the owner does not designate this, but it is safe to assume it
      # will be associated to the object valid types
      def valid_field_types
        owner.try(:valid_field_types) || Type::Object.valid_field_types
      end

      # A little extension of the +is_a?+ method that allows checking it using
      # the +type_klass+
      def of_type?(klass)
        is_a?(klass) || type_klass <= klass
      end

      # Return the class of the type object
      def type_klass
        @type_klass ||= GraphQL.type_map.fetch!(type,
          prevent_register: owner,
          namespaces: namespaces,
        )
      end

      alias type_class type_klass

      # Add the listeners from the associated type
      def all_listeners
        inherited = super
        return inherited unless type_klass.listeners?
        inherited.present? ? inherited + type_klass.all_listeners : type_klass.all_listeners
      end

      # Make sure to check the associated type
      def listeners?
        super || type_klass.listeners?
      end

      # Add the events from the associated type
      def all_events
        inherited = super
        return inherited unless type_klass.events?
        return type_klass.all_events if inherited.blank?
        Helpers.merge_hash_array(inherited, type_klass.all_events)
      end

      # Make sure to check the associated type
      def events?
        super || type_klass.events?
      end

      # Transforms the given value to its representation in a JSON string
      def to_json(value)
        return 'null' if value.nil?
        return type_klass.to_json(value) unless array?
        value.map { |part| type_klass.to_json(part) }
      end

      # Turn the given value into a JSON string representation
      def as_json(value)
        return if value.nil?
        return type_klass.as_json(value) unless array?
        value.map { |part| type_klass.as_json(part) }
      end

      # Turn a user input of this given type into an ruby object
      def deserialize(value)
        return if value.nil?
        return type_klass.deserialize(value) unless array?
        value.map { |val| type_klass.deserialize(val) unless val.nil? }
      end

      # Checks if the type of the field is valid
      def validate!(*)
        super if defined? super

        raise ArgumentError, (+<<~MSG).squish unless type_klass.is_a?(Module)
          Unable to find the "#{type.inspect}" data type on GraphQL context.
        MSG

        valid_type = valid_field_types.empty? || valid_field_types.any? do |base_type|
          type_klass < base_type
        end

        raise ArgumentError, (+<<~MSG).squish unless valid_type
          The "#{type_klass.base_type}" is not accepted in this context.
        MSG
      end

      protected

        # Little helper that shows the type of the field
        def inspect_type
          result = +': '
          result << '[' if array?
          result << type_klass.gql_name
          result << '!' if array? && !nullable?
          result << ']' if array?
          result << '!' unless null?
          result
        end

        # A little hidden helper to support forcing reassignment of type, which
        # should only be done with caution
        def assign_type(type)
          if type.is_a?(Module) && type < GraphQL::Type
            @type_klass = type
            @type = type.to_sym
          else
            @type_klass = nil
            @type = type
          end
        end

        def proxied
          super if defined? super
          extend Field::TypedField::Proxied
        end
    end
  end
end
