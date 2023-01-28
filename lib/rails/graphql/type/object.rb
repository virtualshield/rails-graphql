# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # = GraphQL ObjectType
      #
      # Objects represent a list of named fields, each of which yield a value of
      # a specific type.
      # See http://spec.graphql.org/June2018/#ObjectTypeDefinition
      class Object < Type
        extend ActiveSupport::Autoload
        extend Helpers::WithAssignment
        extend Helpers::WithFields

        include Helpers::Instantiable

        setup! output: true

        self.field_type = Field::OutputField
        self.valid_field_types = [
          Type::Enum,
          Type::Interface,
          Type::Object,
          Type::Scalar,
          Type::Union,
        ].freeze

        autoload :DirectiveObject
        autoload :EnumValueObject
        autoload :FieldObject
        autoload :InputValueObject
        autoload :SchemaObject
        autoload :TypeObject

        # Define the methods for accessing the interfaces of the object
        inherited_collection :interfaces, instance_reader: false

        class << self
          # Plain objects can check if a given value is a valid member
          def valid_member?(value)
            return true if valid_assignment?(value)
            checker = value.is_a?(::Hash) ? :key? : :respond_to?
            value = value.with_indifferent_access if value.is_a?(::Hash)
            fields.values.all? { |field| value.public_send(checker, field.method_name) }
          end

          # Check if the other type is equivalent, by checking if the other is
          # an interface that the current object implements
          def =~(other)
            super || (other.interface? && implements?(other))
          end

          # Use this method to assign interfaces to the object
          def implements(*others, import_fields: true)
            return if others.blank?

            current = all_interfaces&.dup
            others.flat_map do |item|
              item = find_interface!(item)
              next if current&.include?(item) || interfaces.include?(item)

              item.implemented(self, import_fields: import_fields)
              interfaces << item
            end
          end

          # Check if the object implements the given +interface+
          def implements?(interface)
            (object = find_interface(interface)).present? && all_interfaces.include?(object)
          end

          def inspect
            return super if self.eql?(Type::Object)
            fields = @fields.values.map(&:inspect)
            fields = fields.presence && +" {#{fields.join(', ')}}"

            directives = inspect_directives
            directives.prepend(' ') if directives.present?
            +"#<GraphQL::Object #{gql_name}#{fields}#{directives}>"
          end

          private

            # Soft find an object as an +interface+
            def find_interface(object)
              find_interface!(object)
            rescue ArgumentError
              # The object was not found as an actual interface
            end

            # Find a given +object+ and ensures it is an interface
            def find_interface!(object)
              object = GraphQL.type_map.fetch!(object,
                namespaces: namespaces,
                prevent_register: self,
              ) unless object.is_a?(Module) && object < Type::Interface

              return object if object.try(:interface?)
              raise ArgumentError, (+<<~MSG).squish
                The given "#{object}" is not a valid interface.
              MSG
            end
        end

        protected

          def deprecated_directive
            GraphQL::Directive::DeprecatedDirective
          end
      end
    end
  end
end
