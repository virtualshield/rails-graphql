# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold fields during the
      # defition process. Works very similary to Arguments, but it's more
      # flexible, since the type of the fields can be dynamic defined by the
      # class that extends this module.
      #
      # Fields, different from arguments, has extended types, which is somewhat
      # related to the base type, but it's closer associated with the strategy
      # used to handle them.
      module WithFields
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.inherited_collection(:fields, default: {})
          other.class_attribute(:field_types, instance_writer: false, default: [])
          other.class_attribute(:valid_field_types, instance_writer: false, default: [])
        end

        # See {Field}[rdoc-ref:Rails::GraphQL::Field] class.
        def field(name, *args, **xargs, &block)
          object = field_builder.call(name, *args, **xargs, &block)

          raise ArgumentError, <<~MSG.squish if fields.key?(object.name)
            The #{name.inspect} field is already defined and can't be redifined.
          MSG

          object.validate!(valid_field_types)
          fields[object.name] = object
        rescue ArgumentError => e
          raise ArgumentError, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        private

          def field_builder
            field_types.one? ? field_types.first.method(:new) : GraphQL::Field.method(:build)
          end
      end
    end
  end
end
