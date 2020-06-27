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
        def proxy_field(field)
          field = field.instance_variable_get(:@field) if field.is_a?(GraphQL::ProxyField)

          raise ArgumentError, <<~MSG.squish unless field.is_a?(GraphQL::Field)
            The #{field.class.name} is not a valid field.
          MSG

          raise ArgumentError, <<~MSG.squish if field?(field.name)
            The #{field.name.inspect} field is already defined and can't be replaced.
          MSG

          object = GraphQL::ProxyField.new(field, self)
          fields[object.name] = object
        end

        # Overwrite the +:null+ and +:desc+ attributes of a given field named as
        # +name+, it also allows a +block+ which will then further configure the
        # field
        def change_field(name, null: true, desc: nil, &block)
          raise ArgumentError, <<~MSG.squish unless field?(name)
            The #{name.inspect} field is not yet defined.
          MSG

          field = fields[name]
          field.required! unless null
          field.instance_variable_set(:@desc, desc.strip_heredoc.chomp) if desc.present?
          configure(name, &block) if block.present?
        end

        alias overwrite_field change_field

        # Perform extra configurations on a given +field+
        def configure_field(name, &block)
          fields[name].configure(&block) if field?(name)

          raise ArgumentError, <<~MSG.squish
            The #{name.inspect} field is not yet defined.
          MSG
        end

        # Allow accessing fields using the hash notation
        def [](key)
          fields[key.is_a?(String) ? key.underscore.to_sym : key]
        end

        # Check wheter a given field +key+ is defined in the list of fields
        def field?(key)
          fields.key?(key.is_a?(String) ? key.underscore.to_sym : key)
        end

        # Get the list of GraphQL names of all the fields difined
        def field_names
          fields.map(&:gql_name)
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
