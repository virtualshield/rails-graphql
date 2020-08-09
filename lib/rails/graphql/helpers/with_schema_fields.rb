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
          ALIASES = {
            fields:            :fields_for,
            safe_field:        :safe_add_field,
            field:             :add_field,
            proxy_field:       :add_proxy_field,
            association_field: :add_association_field,
            field?:            :has_field?,
          }.freeze

          def arg(*args, **xargs, &block)
            xargs[:owner] ||= source
            GraphQL::Argument.new(*args, **xargs, &block)
          end

          private

            def respond_to_missing?(method_name, include_private = false)
              method_name = ALIASES[method_name] || method_name
              source.respond_to?(method_name, include_private) || super
            end

            def method_missing(method_name, *args, **xargs, &block)
              method_name = ALIASES[method_name] || method_name
              source.send(method_name, type, *args, **xargs, &block)
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

        # Only add the field if it is not already defined
        def safe_add_field(type, *args, of_type: nil, **xargs, &block)
          check_name = xargs[:as] || xargs[:alias] || args.first

          return if (check_name.is_a?(Symbol) || check_name.is_a?(String)) &&
            has_field?(type, check_name)

          method_name = of_type.nil? ? :add_field : "add_#{of_type}_field"
          public_send(method_name, type, *args, **xargs, &block)
        rescue DuplicatedError
          # Do not do anything if it is duplicated
        end

        # Add a new field of the give +type+
        # See {OutputField}[rdoc-ref:Rails::GraphQL::OutputField] class.
        def add_field(type, *args, **xargs, &block)
          xargs[:owner] = self
          object = Field::OutputField.new(*args, **xargs, &block)

          raise DuplicatedError, <<~MSG.squish if has_field?(type, object.name)
            The "#{object.name}" field is already defined on #{type} fields and
            cannot be redefined.
          MSG

          fields_for(type)[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        # Add a new field to the list but use a proxy instead of a hard copy of
        # a given +field+
        def add_proxy_field(type, field, **xargs)
          raise ArgumentError, <<~MSG.squish unless field.is_a?(GraphQL::Field::Core)
            The #{field.class.name} is not a valid field.
          MSG

          xargs[:owner] = self
          object = Field::ProxyField.new(field, **xargs)
          raise DuplicatedError, <<~MSG.squish if has_field?(type, object.name)
            The #{field.name.inspect} field is already defined on #{type} fields
            and cannot be replaced.
          MSG

          fields_for(type)[object.name] = object
        end

        # Add a new field to the list but use a association field, which has
        # dynamic activation
        def add_association_field(type, *args, **xargs, &block)
          xargs[:owner] = self
          xargs[:group] = type
          object = Field::AssociationField.new(*args, **xargs, &block)
          raise DuplicatedError, <<~MSG.squish if field?(object.name || object)
            The #{field.name ? field.name.inspect : 'association'}
            field is already defined and can't be replaced.
          MSG

          fields_for(type)[object.name || object] = object
        end

        # Find a field and then change some flexible attributes of it
        def change_field(type, object, **xargs, &block)
          find_field!(type, object).apply_changes(**xargs, &block)
        end

        alias overwrite_field change_field

        # Run a configuration block for the given +type+
        def configure_field(type, &block)
          schema_scoped_config(self, type).instance_exec(&block)
        end

        # Disable a list of given +fields+ from a given +type+
        def disable_fields(type, *list)
          list.flatten.map { |item| find_field(type, item)&.disable! }
        end

        # Enable a list of given +fields+ from a given +type+
        def enable_fields(type, *list)
          list.flatten.map { |item| find_field(type, item)&.enable! }
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

        # Get the list of GraphQL names of all the fields difined
        def field_names_for(type, enabled_only = true)
          (enabled_only ? fields_for(type).select(&:enabled?) : fields_for(type))
            .map(&:gql_name).compact
        end

        # Run a configuration block for the given +type+
        def config_field(type, &block)
          schema_scoped_config(self, type).instance_exec(&block)
        end

        # Validate all the fields to make sure the definition is valid
        def validate!(*)
          super if defined? super

          # TODO: Maybe find a way to freeze the fields, since after validation
          # the best thing to do is block changes
          SCHEMA_FIELD_TYPES.each_key do |kind|
            next unless instance_variable_defined?("@#{kind}_fields")
            instance_variable_get("@#{kind}_fields")&.each_value(&:validate!)
          end

          nil # No exception already means valid
        end

        SCHEMA_FIELD_TYPES.each_key do |kind|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{kind}_field?(name)
              field?(:#{kind}, name)
            end

            def #{kind}_fields(&block)
              return @#{kind}_fields ||= Concurrent::Map.new if block.nil?
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
                fields: @#{kind}_fields || nil,
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
