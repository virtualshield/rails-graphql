# frozen_string_literal: true

module Rails
  module GraphQL
    class Source
      class Base < GraphQL::Source
        extend Helpers::WithSchemaFields
        extend Helpers::WithAssignment
        extend Helpers::Unregisterable

        self.abstract = true

        # The name of the class (or the class itself) to be used as superclass
        # for the generate GraphQL object type of this source
        class_attribute :object_class, instance_accessor: false,
          default: '::Rails::GraphQL::Type::Object'

        # The name of the class (or the class itself) to be used as superclass
        # for the generate GraphQL input type of this source
        class_attribute :input_class, instance_accessor: false,
          default: '::Rails::GraphQL::Type::Input'

        # Allow defining a name for the object without going to many troubles
        # like overriding methods
        class_attribute :object_name, instance_accessor: false

        # Allow defining a name for the input without going to many troubles
        # like overriding methods
        class_attribute :input_name, instance_accessor: false

        class << self

          # Unregister all objects that this source was providing
          def unregister!
            @object = @input = nil
            super
          end

          # Return the GraphQL object type associated with the source. It will
          # create one if it's not defined yet. The created class will be added
          # to the +::GraphQL+ namespace with the addition of any namespace of
          # the current class
          def object
            @object ||= create_type(superclass: object_class, gql_name: object_name).tap do |t|
              t.include(const_get(:ObjectMethods)) if const_defined?(:ObjectMethods, false)
            end
          end

          # Return the GraphQL input type associated with the source. It will
          # create one if it's not defined yet. The created class will be added
          # to the +::GraphQL+ namespace with the addition of any namespace of
          # the current class
          def input
            @input ||= create_type(superclass: input_class, gql_name: input_name).tap do |t|
              t.include(const_get(:InputMethods)) if const_defined?(:InputMethods, false)
            end
          end

          protected

            # A helper method to create an enum type
            def create_enum(enum_name, values, **xargs, &block)
              enumerator = values.each_pair if values.respond_to?(:each_pair)
              enumerator ||= values.each.with_index

              xargs[:values] = enumerator.sort_by(&:last).map(&:first)
              xargs[:indexed] = enumerator.first.last.is_a?(Numeric)

              create_type(:enum, enum_name.to_s.classify, **xargs, &block)
            end

            # Helper method to create a class based on the given +type+ and
            # allows several other settings to be executed on it
            def create_type(type = nil, name = nil, **xargs, &block)
              xargs[:owner] ||= self
              xargs[:namespaces] = namespaces
              xargs[:assigned_to] = safe_assigned_class
              superclass = xargs.delete(:superclass) || type

              name ||= base_name.tr('_', '')
              GraphQL::Type.create!(self, name, superclass, **xargs, &block)
            end

            # Allow setting methods on the source object via a proper module
            def object_methods(&block)
              type_extend_with_module(:object, &block)
            end

            # Allow setting methods on the source input via a proper module
            def input_methods(&block)
              type_extend_with_module(:input, &block)
            end

          private

            # Allows adding methods to a type by properly providing a module
            # and adding it to the type
            def type_extend_with_module(type, &block)
              mod_name = :"#{type.to_s.classify}Methods"
              mod = const_get(mod_name) if const_defined?(mod_name, false)
              mod ||= const_set(mod_name, Module.new).tap do |m|
                instance_variable_get("@#{type}")&.include(m)
              end

              mod.module_eval(&block)
            end

        end
      end
    end
  end
end
