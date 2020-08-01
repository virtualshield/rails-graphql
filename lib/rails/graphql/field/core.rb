# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Due to the flexibility of fields, this module implements the main features
    # of a filed, that later can be implemented in all sorts of classes
    module Field::Core
      delegate :input_type?, :output_type?, :leaf_type?, :proxy?,
        :from_ar?, :from_ar, to: :class

      delegate :namespaces, to: :owner

      attr_reader :name, :gql_name, :owner

      def self.included(other)
        other.extend(ClassMethods)
      end

      module ClassMethods
        # This returns the base type of the field. Normally is handled by a
        # typed class, but further implementations are allowed
        def kind
        end

        # Normally extended fields cannot be serialized during a query. But, by
        # having this and the +from_ar+ methods, other classes can override them
        # and provide a valid fetcher.
        def from_ar?(*)
        end

        # Just to ensure the compatibility with other outputs.
        def from_ar(*)
        end

        # Defines if the current field is valid as an input type
        def input_type?
          false
        end

        # Defines if the current field is valid as an output type
        def output_type?
          false
        end

        # Defines if the current field is considered a leaf output
        def leaf_type?
          false
        end

        # Checks if the the field is a proxy kind of field
        def proxy?
          false
        end
      end

      # Apply a controlled set of changes to the field
      def apply_changes(**xargs, &block)
        required! unless xargs.fetch(:null, true)
        disable! if xargs.fetch(:disabled, false)
        enable! if xargs.fetch(:enabled, false)

        @desc = xargs[:desc].strip_heredoc.chomp if xargs.key?(:desc)
        configure(&block) if block.present?
      end

      # Allow extra configurations to be performed using a block
      def configure(&block)
        Field::ScopedConfig.new(self, block.binding.receiver).instance_exec(&block)
      end

      # Returns the name of the method used to retrieve the information
      def method_name
        defined?(@method_name) ? @method_name : @name
      end

      # Check if the other field is equivalent
      def =~(other)
        (defined? super ? super : true) &&
          other.gql_name == gql_name &&
          (other.null? == null? || other.null? && !null?) &&
          other.array? == array? &&
          other.nullable? == nullable? &&
          match_arguments?(other)
      end

      # Checks if the argument can be null
      def null?
        @null
      end

      # Checks if the argument can be an array
      def array?
        @array
      end

      # Checks if the argument can have null elements in the array
      def nullable?
        @nullable
      end

      # Check if tre field is enabled
      def enabled?
        @enabled
      end

      # Check if tre field is disabled
      def disabled?
        !enabled?
      end

      # Mark the field as globally enabled
      def enable!
        @enabled = true
      end

      # Mark the field as globally disabled
      def disable!
        @enabled = false
      end

      # Return the description of the argument
      def description
        @desc
      end

      # Checks if a description was provided
      def description?
        !!@desc
      end

      # Check if the field is an internal one
      def internal?
        name.start_with?('__')
      end

      # This method must be overridden by children classes
      def valid_input?(*)
        false
      end

      # This method must be overridden by children classes
      def valid_output?(*)
        false
      end

      # Transforms the given value to its representation in a JSON string
      def to_json(value)
        to_hash(value).inspect
      end

      # Turn the given value into a JSON string representation
      def to_hash(value)
        return nil if value.nil?
        return type_klass.to_hash(value) unless array?
        value.map { |part| type_klass.to_hash(part) }
      end

      # Turn a user input of this given type into an ruby object
      def deserialize(value)
        return if value.nil?
        return type_klass.deserialize(value) unless array?
        value.map { |val| type_klass.deserialize(val) unless val.nil? }
      end

      # Check if the given value is valid using +valid_input?+ or
      # +valid_output?+ depending of the type of the field
      def valid?(value)
        input_type? ? valid_input?(value) : valid_output?(value)
      end

      # Checks if the definition of the field is valid.
      def validate!(*)
        super if defined? super

        raise NameError, <<~MSG.squish if internal? && !owner.try(:spec_object)
          The name "#{gql_name}" is invalid. Only internal fields from the
          spec can have a name starting with "__".
        MSG

        nil # No exception already means valid
      end

      # Update the null value
      def required!
        @null = false
      end

      protected

        def normalize_name(value)
          return if value.blank?

          @name = value.to_s.underscore.to_sym

          @gql_name = @name.to_s.camelize(:lower)
          @gql_name.prepend('__') if internal?
        end

        def match_arguments?(other)
          other.all_arguments.size == all_arguments.size &&
            other.all_arguments.all? { |key, arg| arg == all_arguments[key] }
        end

        def inspect_directives
          dirs = all_directives.map(&:inspect)
          dirs.presence && " #{dirs.join(' ')}"
        end

        def inspect_arguments
          args = all_arguments.each_value.map(&:inspect)
          args.presence && "(#{args.join(', ')})"
        end
    end
  end
end
