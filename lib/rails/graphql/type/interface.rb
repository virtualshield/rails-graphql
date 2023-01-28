# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # = GraphQL InterfaceType
      #
      # Interfaces represent a list of named fields and their types.
      # See http://spec.graphql.org/June2018/#InterfaceTypeDefinition
      #
      # This class doesn't implements +valid_output?+ nor any of the output like
      # methods because the Object class that uses interface already fetches
      # all the fields for its composition and does the validating and
      # serializing process.
      class Interface < Type
        extend Helpers::WithAssignment
        extend Helpers::WithFields

        include Helpers::Instantiable

        setup! output: true

        self.field_type = Field::OutputField

        # Define the methods for accessing the types attribute
        inherited_collection :types, instance_reader: false

        class << self
          # Check if the other type is equivalent, by checking if the other is
          # an object and the object implements this interface
          def =~(other)
            super || (other.object? && other.implements?(self))
          end

          # When attaching an interface to an object, copy the fields and add to
          # the list of types. Pre-existing same-named fields with are not
          # equivalent produces an exception.
          def implemented(object, import_fields: true)
            import_fields = false if abstract?

            fields.each do |name, field|
              defined = object[field.name]
              raise ArgumentError, (+<<~MSG).squish unless defined || import_fields
                The "#{object.gql_name}" object must have a "#{field.gql_name}" field.
              MSG

              invalid = defined && defined !~ field
              raise ArgumentError, (+<<~MSG).squish if invalid
                The "#{object.gql_name}" object already has a "#{field.gql_name}" field and it
                is not equivalent to the one defined on the "#{gql_name}" interface.
              MSG

              object.proxy_field(field) if import_fields && !defined
            end

            types << object
          end

          def inspect
            return super if self.eql?(Type::Interface)
            fields = @fields.values.map(&:inspect) if defined?(@fields)
            fields = fields.presence && +" {#{fields.join(', ')}}"

            directives = inspect_directives
            directives.prepend(' ') if directives.present?
            +"#<GraphQL::Interface #{gql_name}#{fields}#{directives}>"
          end

          # Check if the given object is properly implementing this interface
          def validate(*)
            # Don't validate interfaces since the fields are copied and
            # the interface might have broken field types due to namespaces
          end
        end
      end
    end
  end
end
