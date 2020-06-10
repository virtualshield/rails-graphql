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

          raise ArgumentError, <<~MSG.squish if fields.key?(object.name)
            The #{name.inspect} field is already defined and can't be redefined.
          MSG

          fields[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        private

          def field_builder
            field_types.one? ? field_types.first.method(:new) : GraphQL::Field.method(:build)
          end
      end
    end
  end
end
