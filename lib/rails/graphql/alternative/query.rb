# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Alternative Query
    #
    # This object acts like a field, but is organized as an object for extended
    # resolvers or really complex fields.
    class Alternative::Query
      extend Helpers::WithNamespace
      include Helpers::Instantiable

      # An abstract class will not have its field imported
      class_attribute :abstract, instance_accessor: false, default: false
      self.abstract = true

      class << self
        delegate :gql_name, :to_sym, :desc, :argument, :ref_argument, :id_argument,
          :use, :internal?, :disabled?, :enabled?, :disable!, :enable!, :rename!,
          :authorize, :on, :description=, :description, to: :field

        # Returns the type of the field class
        def type_field_class
          :query
        end

        # Alias does not work because of the override
        def i18n_scope(*)
          type_field_class
        end

        # Stores the underlying field of the object
        def field
          return @field if defined?(@field)
          return define_field unless superclass.instance_variable_defined?(:@field)
          import_field(superclass.field)
        end

        def inspect
          defined?(@field) ? @field.inspect : super
        end

        protected

          # Mark the given class to be pending of registration
          def inherited(subclass)
            subclass.abstract = false
            super if defined? super
          end

          # Create a new field for the class
          def define_field(field_name = nil, type = :any, **xargs, &blcok)
            field_name ||= anonymous? ? '_anonymous' : begin
              type_module = type_field_class.to_s.classify.pluralize
              user_name = name.split(+"#{type_module}::")[1]
              user_name ||= name.delete_prefix('GraphQL::')
              user_name.tr(':', '')
            end

            # Save the generated field ensuring the owner
            @field = field_class.new(field_name, type, **xargs, owner: self, &blcok)
          end

          # Import the field from a given source
          def import_field(other_field, **xargs, &blcok)
            @field = other_field.to_proxy(**xargs, owner: self, &blcok)
          end

          # Change the return type of the field
          def returns(type, **xargs)
            full     = xargs.fetch(:full, false)
            null     = full ? false : xargs.fetch(:null, true)
            array    = full ? true  : xargs.fetch(:array, false)
            nullable = full ? false : xargs.fetch(:nullable, true)

            field.send(:assign_type, type)
            field.instance_variable_set(:@null, null)
            field.instance_variable_set(:@array, array)
            field.instance_variable_set(:@nullable, nullable)
          end

        private

          # Return the class of the underlying field
          def field_class
            return @field.class if defined?(@field)
            list = Helpers::WithSchemaFields::TYPE_FIELD_CLASS
            GraphQL::Field.const_get(list[type_field_class])
          end
      end
    end
  end
end
