# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold schema fields (query,
      # mutation, and subscription fields). Works very similar to fields, but
      # they are placed in different places regarding their type.
      module WithSchemaFields
        SCHEMA_FIELD_TYPES = %i[query mutation subscription].map do |key|
          [key, "_#{key.to_s.classify}"]
        end.to_h.freeze

        class ScopedConfig < Struct.new(:source, :type) # :nodoc: all
          def arg(*args, **xargs, &block)
            xargs[:owner] = source
            GraphQL::Argument.new(*args, **xargs, &block)
          end

          def fields
            source.fields_for(type)
          end

          def field(*args, **xargs, &block)
            source.add_field(type, *args, **xargs, &block)
          end

          def proxy_field(field)
            source.add_proxy_field(type, field)
          end

          def change_field(field, **xargs, &block)
            source.change_field(type, field, **xargs, &block)
          end

          alias overwrite_field change_field

          def configure_field(field, &block)
            source.find_field!(type, field).configure(&block)
          end

          def disable_fields(*list)
            source.disable_fields(type, *list)
          end

          def enable_fields(*list)
            source.enable_fields(type, *list)
          end
        end

        # A little helper for getting the list of fields of a given type
        def fields_for(type)
          public_send("#{type}_fields")
        end

        # Return the object name for a given +type+ of list of fields
        def type_name_for(type)
          SCHEMA_FIELD_TYPES[type]
        end

        # Add a new field of the give +type+
        # See {OutputField}[rdoc-ref:Rails::GraphQL::OutputField] class.
        def add_field(type, *args, **xargs, &block)
          xargs[:owner] = self
          object = Field::OutputField.new(*args, **xargs, &block)

          raise ArgumentError, <<~MSG.squish if has_field?(type, object.name)
            The "#{object.name}" field is already defined on #{type} fields and
            cannot be redefined.
          MSG

          fields_for(type)[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        # Add a new field to the list but use a proxy instead of a hard copy of
        # a given +field+
        def add_proxy_field(type, field)
          field = field.instance_variable_get(:@field) if field.is_a?(GraphQL::ProxyField)

          raise ArgumentError, <<~MSG.squish unless field.is_a?(GraphQL::Field)
            The #{field.class.name} is not a valid field.
          MSG

          raise ArgumentError, <<~MSG.squish if has_field?(type, field.name)
            The #{field.name.inspect} field is already defined on #{type} fields
            and cannot be replaced.
          MSG

          object = GraphQL::ProxyField.new(field, self)
          fields_for(type)[object.name] = object
        end

        # Check if a field of the given +type+ exists. The +object+ can be the
        # +gql_name+, +name+, or an actual field.
        def has_field?(type, object)
          object = object.name if object.is_a?(GraphQL::Field)
          fields_for(type).key?(object.is_a?(String) ? object.underscore.to_sym : object)
        end

        # Find a specific field on the given +type+ list. The +object+ can be
        # the +gql_name+, +name+, or an actual field.
        def find_field(type, object)
          object = object.name if object.is_a?(GraphQL::Field)
          fields_for(type)[object.is_a?(String) ? object.underscore.to_sym : object]
        end

        # If the field is not found it will raise an exception
        def find_field!(type, object)
          find_field(type, object) || raise(::ArgumentError, <<~MSG.squish)
            The #{object.inspect} field on #{type} is not defined yet.
          MSG
        end

        # Find a field and then change some flexible attributes of it
        def change_field(type, object, **xargs, &block)
          find_field!(type, object).apply_changes(**xargs, &block)
        end

        alias overwrite_field change_field

        # Disable a list of given +fields+ from a given +type+
        def disable_fields(type, *list)
          list.flatten.map { |item| find_field(type, item)&.disable! }
        end

        # Enable a list of given +fields+ from a given +type+
        def enable_fields(type, *list)
          list.flatten.map { |item| find_field(type, item)&.enable! }
        end

        # Run a configuration block for the given +type+
        def config_field(type, &block)
          schema_scoped_config(self, type).instance_exec(&block)
        end

        SCHEMA_FIELD_TYPES.keys.each do |kind|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{kind}_field?(name)
              field?(:#{kind}, name)
            end

            def #{kind}_fields(&block)
              return @#{kind}_fields ||= {} if block.nil?
              config_field(:#{kind}, &block)
              @#{kind}_fields
            end

            def #{kind}_type_name
              SCHEMA_FIELD_TYPES[:#{kind}]
            end

            def #{kind}_type
              OpenStruct.new(
                kind: :object,
                object?: true,
                kind_enum: 'OBJECT',
                fields: #{kind}_fields,
                gql_name: #{kind}_type_name,
                interfaces: nil,
                description: nil,
                interfaces?: false,
              )
            end
          RUBY
        end

        protected

          # Create a new instace of the +ScopedConfig+ class
          def schema_scoped_config(*args)
            WithSchemaFields::ScopedConfig.new(*args)
          end
      end
    end
  end
end
