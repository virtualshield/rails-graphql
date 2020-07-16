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
          other.define_singleton_method(:fields) { @fields ||= {} }
          other.class_attribute(:field_types, instance_writer: false, default: [])
          other.class_attribute(:valid_field_types, instance_writer: false, default: [])
        end

        module ClassMethods # :nodoc: all
          def inherited(subclass)
            super if defined? super
            return if fields.empty?

            new_fields = fields.transform_values do |item|
              item.dup.tap { |x| x.instance_variable_set(:@owner, subclass) }
            end

            subclass.instance_variable_set(:@fields, new_fields)
          end
        end

        # Validate all the fields to make sure the definition is valid
        def validate!(*)
          super if defined? super
          fields.each_value(&:validate!)
          nil # No exception already means valid
        end

        # See {Field}[rdoc-ref:Rails::GraphQL::Field] class.
        def field(name, *args, **xargs, &block)
          xargs[:owner] = self
          object = field_builder.call(name, *args, **xargs, &block)

          raise ArgumentError, <<~MSG.squish if field?(object.name)
            The #{name.inspect} field is already defined and can't be redefined.
          MSG

          fields[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        # Add a new field to the list but use a proxy instead of a hard copy of
        # a given +field+
        def proxy_field(field, **xargs)
          valid = field.is_a?(GraphQL::Field) || field.is_a?(GraphQL::ProxyField)
          raise ArgumentError, <<~MSG.squish unless valid
            The #{field.class.name} is not a valid field.
          MSG

          raise ArgumentError, <<~MSG.squish if field?(field.name)
            The #{field.name.inspect} field is already defined and can't be replaced.
          MSG

          object = GraphQL::ProxyField.new(field, self, **xargs)
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
        def field_names
          fields.map(&:gql_name)
        end

        protected

          # A little helper to define arguments using the :arguments key
          def arg(*args, **xargs, &block)
            xargs[:owner] = self
            GraphQL::Argument.new(*args, **xargs, &block)
          end

        private

          # TODO: Probably remove this since we don't have the build method and
          # we probably won't need it anymore
          def field_builder
            field_types.one? ? field_types.first.method(:new) : GraphQL::Field.method(:build)
          end
      end
    end
  end
end
