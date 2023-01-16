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

        class << self

          # Unregister all objects that this source was providing
          def unregister!
            GraphQL.type_map.unregister(*created_types) if defined?(@created_types)
            @object = @input = nil
          end

          # Return the GraphQL object type associated with the source. It will
          # create one if it's not defined yet. The created class will be added
          # to the +::GraphQL+ namespace with the addition of any namespace of
          # the current class
          def object
            @object ||= create_type(superclass: object_class)
          end

          # Return the GraphQL input type associated with the source. It will
          # create one if it's not defined yet. The created class will be added
          # to the +::GraphQL+ namespace with the addition of any namespace of
          # the current class
          def input
            @input ||= create_type(superclass: input_class)
          end

          protected

            # A helper method to create an enum type
            def create_enum(enum_name, values, **xargs, &block)
              enumerator = values.each_pair if values.respond_to?(:each_pair)
              enumerator ||= values.each.with_index

              xargs = xargs.reverse_merge(once: true)
              create_type(:enum, as: enum_name.classify, **xargs) do
                indexed! if enumerator.first.last.is_a?(Numeric)
                enumerator.sort_by(&:last).map(&:first).each(&method(:add))
                instance_exec(&block) if block.present?
              end
            end

            # Helper method to create a class based on the given +type+ and
            # allows several other settings to be executed on it
            def create_type(type = nil, **xargs, &block)
              name = "#{gql_module.name}::#{xargs.delete(:as) || base_name}"
              superclass = xargs.delete(:superclass)
              with_owner = xargs.delete(:with_owner)

              if superclass.nil?
                superclass = type.to_s.classify
              elsif superclass.is_a?(String)
                superclass = superclass.constantize
              end

              source = self
              Schema.send(:create_type, name, superclass, **xargs) do
                include Helpers::WithOwner if with_owner
                set_namespaces(*source.namespaces)

                self.owner = source if respond_to?(:owner=)
                self.assigned_to = source.safe_assigned_class \
                  if source.assigned? && is_a?(Helpers::WithAssignment)

                instance_exec(&block) if block.present?
              end.tap { |klass| created_types << klass }
            end

          private

            # Keep track of all the types created byt this source
            def created_types
              @created_types ||= []
            end

        end

      end
    end
  end
end
