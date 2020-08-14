# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold fields during the
      # definition process. Works very similar to Arguments, but it's more
      # flexible, since the type of the fields can be dynamic defined by the
      # class that extends this module.
      #
      # Fields, different from arguments, has extended types, which is somewhat
      # related to the base type, but it's closer associated with the strategy
      # used to handle them.
      module WithFields
        def self.extended(other)
          other.extend(WithFields::ClassMethods)
          other.define_singleton_method(:fields) { @fields ||= Concurrent::Map.new }
          other.class_attribute(:field_type, instance_writer: false)
          other.class_attribute(:valid_field_types, instance_writer: false, default: [])
        end

        module ClassMethods # :nodoc: all
          def inherited(subclass)
            super if defined? super
            return unless defined?(@fields)
            fields.each_value(&subclass.method(:proxy_field))
          end
        end

        # Check if the field is already defined before actually creating it
        def safe_field(*args, of_type: nil, **xargs, &block)
          method_name = of_type.nil? ? :field : "#{of_type}_field"
          public_send(method_name, *args, **xargs, &block)
        rescue DuplicatedError
          # Do not do anything if it is duplicated
        end

        # See {Field}[rdoc-ref:Rails::GraphQL::Field] class.
        def field(name, *args, **xargs, &block)
          xargs[:owner] = self
          object = field_type.new(name, *args, **xargs, &block)

          raise DuplicatedError, <<~MSG.squish if field?(object.name)
            The #{name.inspect} field is already defined and can't be redefined.
          MSG

          fields[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        # Add a new field to the list but use a proxy instead of a hard copy of
        # a given +field+
        def proxy_field(field, *args, **xargs, &block)
          raise ArgumentError, <<~MSG.squish unless field.is_a?(GraphQL::Field)
            The #{field.class.name} is not a valid field.
          MSG

          xargs[:owner] = self
          object = field.to_proxy(*args, **xargs, &block)
          raise DuplicatedError, <<~MSG.squish if field?(object.name)
            The #{field.name.inspect} field is already defined and can't be replaced.
          MSG

          fields[object.name] = object
        end

        # Overwrite attributes of a given field named as +name+, it also allows
        # a +block+ which will then further configure the field
        def change_field(object, **xargs, &block)
          find_field!(object).apply_changes(**xargs, &block)
        end

        alias overwrite_field change_field

        # Perform extra configurations on a given +field+
        def configure_field(object, &block)
          find_field!(object).configure(&block)
        end

        # Disable a list of given +fields+
        def disable_fields(*list)
          list.flatten.map { |item| self[item]&.disable! }
        end

        # Enable a list of given +fields+
        def enable_fields(*list)
          list.flatten.map { |item| self[item]&.enable! }
        end

        # Check wheter a given field +object+ is defined in the list of fields
        def field?(object)
          object = object.name if object.is_a?(GraphQL::Field)
          fields.key?(object.is_a?(String) ? object.underscore.to_sym : object)
        end

        # Allow accessing fields using the hash notation
        def [](object)
          object = object.name if object.is_a?(GraphQL::Field)
          fields[object.is_a?(String) ? object.underscore.to_sym : object]
        end

        alias find_field []

        # If the field is not found it will raise an exception
        def find_field!(object)
          find_field(object) || raise(::ArgumentError, <<~MSG.squish)
            The #{object.inspect} field is not defined yet.
          MSG
        end

        # Get the list of GraphQL names of all the fields difined
        def field_names(enabled_only = true)
          (enabled_only ? enabled_fields : fields).each_value.map(&:gql_name).compact
        end

        # Return a lazy enumerator for enabled fields
        def enabled_fields
          fields.select { |_, field| field.enabled? }
        end

        # Validate all the fields to make sure the definition is valid
        def validate!(*)
          super if defined? super

          # TODO: Maybe find a way to freeze the fields, since after validation
          # the best thing to do is block changes
          fields.each_value(&:validate!)
        end

        protected

          # A little helper to define arguments using the :arguments key
          def arg(*args, **xargs, &block)
            xargs[:owner] = self
            GraphQL::Argument.new(*args, **xargs, &block)
          end
      end
    end
  end
end
