# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module that allows other objects to hold fields during the
      # definition process. Works very similar to Arguments, but it's more
      # flexible, since the type of the fields can be dynamic defined by the
      # class that extends this module.
      #
      # Fields, different from arguments, has extended types, which is somewhat
      # related to the base type, but it's closer associated with the strategy
      # used to handle them.
      module WithFields
        module ClassMethods
          def inherited(subclass)
            super if defined? super
            return unless defined?(@fields)
            fields.each_value(&subclass.method(:proxy_field))
          end

          # Return the list of fileds, only initialize when explicitly told
          def fields(initialize = nil)
            return @fields if defined?(@fields)
            return unless initialize

            @fields = Concurrent::Map.new
          end

          # Check if there are any fields defined
          def fields?
            defined?(@fields) && @fields.present?
          end
        end

        def self.extended(other)
          other.extend(WithFields::ClassMethods)
          other.class_attribute(:field_type, instance_accessor: false)
          other.class_attribute(:valid_field_types, instance_accessor: false, default: [])
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
          object = field_type.new(name, *args, **xargs, owner: self, &block)

          raise DuplicatedError, (+<<~MSG).squish if field?(object.name)
            The #{name.inspect} field is already defined and can't be redefined.
          MSG

          fields(true)[object.name] = object
        rescue DefinitionError => e
          raise e.class, +"#{e.message}\n  Defined at: #{caller(2)[0]}"
        end

        # Add a new field to the list but use a proxy instead of a hard copy of
        # a given +field+
        def proxy_field(field, *args, **xargs, &block)
          raise ArgumentError, (+<<~MSG).squish unless field.is_a?(field_type)
            The #{field.class.name} is not a valid field.
          MSG

          xargs[:owner] = self
          object = field.to_proxy(*args, **xargs, &block)
          raise DuplicatedError, (+<<~MSG).squish if field?(object.name)
            The #{field.name.inspect} field is already defined and can't be replaced.
          MSG

          fields(true)[object.name] = object
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
          return false unless fields?
          object = object.name if object.is_a?(GraphQL::Field)
          fields.key?(object.is_a?(String) ? object.underscore.to_sym : object)
        end

        # Allow accessing fields using the hash notation
        def find_field(object)
          return unless fields?
          object = object.name if object.is_a?(GraphQL::Field)
          fields[object.is_a?(String) ? object.underscore.to_sym : object]
        end

        alias [] find_field

        # If the field is not found it will raise an exception
        def find_field!(object)
          find_field(object) || raise(NotFoundError, (+<<~MSG).squish)
            The #{object.inspect} field is not defined yet.
          MSG
        end

        # Get the list of GraphQL names of all the fields difined
        def field_names(enabled_only = true)
          (enabled_only ? enabled_fields : lazy_each_field)&.map(&:gql_name)&.eager
        end

        # Return a lazy enumerator for enabled fields
        def enabled_fields
          lazy_each_field&.select(&:enabled?)
        end

        # Import one or more field into the current list of fields
        def import(klass, ignore_abstract: false)
          return if ignore_abstract && klass.try(:abstract?)

          if klass.is_a?(Module) && klass <= Alternative::Query
            # Import an alternative declaration of a field
            proxy_field(klass.field)
          elsif klass.is_a?(Helpers::WithFields)
            # Import a set of fields
            klass.fields.each_value { |field| proxy_field(field) }
          else
            return if GraphQL.config.silence_import_warnings
            GraphQL.logger.warn(+"Unable to import #{klass.inspect} into #{self.name}.")
          end
        end

        # Import a module containing several classes to be imported
        def import_all(mod, recursive: false, ignore_abstract: false)
          mod.constants.each do |const_name|
            object = mod.const_get(const_name)

            if object.is_a?(Class)
              import(object, ignore_abstract: ignore_abstract)
            elsif object.is_a?(Module) && recursive
              # TODO: Maybe add deepness into the recursive value
              import_all(object, recursive: recursive, ignore_abstract: ignore_abstract)
            end
          end
        end

        # Validate all the fields to make sure the definition is valid
        def validate!(*)
          super if defined? super

          # TODO: Maybe find a way to freeze the fields, since after validation
          # the best thing to do is block changes
          fields&.each_value(&:validate!)
        end

        # Find a specific field using its id as +gql_name.type+
        def find_by_gid(gid)
          find_field!(gid.name)
        end

        protected

          # A little helper to define arguments using the :arguments key
          def arg(*args, **xargs, &block)
            xargs[:owner] = self
            GraphQL::Argument.new(*args, **xargs, &block)
          end

        private

          def lazy_each_field
            fields.each_pair.lazy.each_entry.map(&:last) if fields?
          end
      end
    end
  end
end
