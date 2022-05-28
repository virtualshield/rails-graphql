# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Alternative Query
    #
    # This object acts like a field, but is organized as an object for extended
    # resolvers or really complex fields.
    class Alternative::Query
      include Helpers::Instantiable

      # An abstract class will not have its field imported
      class_attribute :abstract, instance_accessor: false, default: false
      self.abstract = true

      class << self
        delegate :gql_name, :to_sym, :desc, :argument, :ref_argument, :id_argument,
          :use, :internal?, :disabled?, :enabled?, :disable!, :enable!, :rename!,
          :authorize, :on, to: :@field, allow_nil: true

        # Returns the type of the field class
        def type_field_class
          :query
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

          # Stores the underlying field of the object
          def field
            return @field if defined?(@field)
            return define_field unless superclass.instance_variable_defined?(:@field)
            import_field(superclass.field)
          end

          # Create a new field for the class
          def define_field(name = nil, type = :any, **xargs, &blcok)
            name ||= anonymous? ? '_anonymous' : begin
              use_name = name.match(WithName::NAME_EXP).try(:[], 1)&.tr(':', '')
              use_name.sub!(/\A#{type_field_class.to_s.classify.pluralize}/, '')
            end

            # Save the generated field ensuring the owner
            @field = field_class.new(name, type, **xargs, owner: self, &blcok)
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
            GraphQL::Field.const_get(WithSchemaFields::TYPE_FIELD_CLASS[type_field_class])
          end
      end
    end
  end
end
