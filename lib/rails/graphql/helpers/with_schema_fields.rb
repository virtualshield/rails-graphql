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
          def fields
            source.fields_for(type)
          end

          def field(*args, **xargs, &block)
            source.add(type, *args, **xargs, &block)
          end

          def proxy_field(field)
            source.add_proxy(type, field)
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
        def add(type, *args, **xargs, &block)
          xargs[:owner] = self
          object = Field::OutputField.new(*args, **xargs, &block)

          raise ArgumentError, <<~MSG.squish if has_field?(type, object.name)
            The #{name.inspect} field is already defined on #{type} fields and
            cannot be redefined.
          MSG

          fields_for(type)[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        # Remove the given list of +fields+ from the fields of the given +type+
        def remove(type, *fields)
          fields_for(type).except!(*fields)
        end

        # Add a new field to the list but use a proxy instead of a hard copy of
        # a given +field+
        def add_proxy(type, field)
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

        # Run a configuration block for the given +type+
        def config(type, &block)
          schema_scoped_config(self, type).instance_exec(&block)
        end

        SCHEMA_FIELD_TYPES.keys.each do |kind|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{kind}_field?(name)
              field?(:#{kind}, name)
            end

            def #{kind}_fields(&block)
              return @#{kind}_fields ||= {} if block.nil?
              config(:#{kind}, &block)
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
