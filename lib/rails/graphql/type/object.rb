# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL ObjectType
      #
      # Objects represent a list of named fields, each of which yield a value of
      # a specific type.
      # See http://spec.graphql.org/June2018/#ObjectTypeDefinition
      class Object < Type
        extend ActiveSupport::Autoload
        extend Helpers::WithFields

        setup! output: true

        self.field_types = [Field::OutputField].freeze
        self.valid_field_types = [
          Type::Enum,
          Type::Interface,
          Type::Object,
          Type::Scalar,
          Type::Union,
        ].freeze

        eager_autoload do
          autoload :ActiveRecordObject
          autoload :AssignedObject

          autoload :DirectiveObject
          autoload :EnumValueObject
          autoload :FieldObject
          autoload :InputValueObject
          autoload :SchemaObject
          autoload :TypeObject
        end

        # Define the methods for accessing the interfaces of the object
        inherited_collection :interfaces

        class << self
          # Check if the other type is equivalent, by checking if the other is
          # an interface that the current object implements
          def ==(other)
            super || (other.interface? && implements?(other))
          end

          # Objects cannot be serialized on queries, since they are originally
          # complex objects. This will be overridden whenever a object can in
          # fact be serialized during a query process.
          def from_ar?(*)
            false
          end

          # Just to ensure the compatibility with other outputs
          def from_ar(*)
          end

          # Check if a given value is a valid non-serialized output
          def valid_output?(value, list = nil)
            return false unless list.blank? || (list - field_names).eql?(0)
            (list.presence || field_names).all? do |field_name|
              # It's okay to use to_sym since we already check that all given
              # names exist in the list of fields
              field = self[field_name]

              # TODO: Change this when we have the resolvers
              value.respond_to?(field.method_name) || value.try(:key?, field.method_name)
            end
          end

          # Transforms the given value to its representation in a JSON string
          # getting only the given +list+ of fields. This exists mainly for
          # compatibility reasons, because requests will deal with objects in a
          # different way
          def to_json(value, list = nil)
            to_hash(value, list).to_json
          end

          # Transforms the given value to its representation in a Hash object
          # getting only the given +list of fields+ This exists mainly for
          # compatibility reasons, because requests will deal with objects in a
          # different way
          def to_hash(value, list = nil)
            (list.presence || field_names).inject({}) do |result, field_name|
              # We assume that +valid_output?+ was used against +value+
              field = self[field_name]

              # TODO: Change this when we have the resolvers
              val = value.respond_to?(field.method_name) \
                ? value.public_send(field.method_name) \
                : value.try(:[], field.method_name)

              result.merge!(field_name => val)
            end
          end

          # Use this method to assign interfaces to the object
          def implements(*others)
            return if others.blank?

            others.flatten!
            others.map! do |item|
              next item unless item.is_a?(Symbol)
              GraphQL.type_map.fetch!(item, namespaces: namespaces)
            end

            raise ArgumentError, <<~MSG.squish unless others.all?(&:interface?)
              One or more items are not valid interfaces.
            MSG

            merge_fields(*others)
            interfaces.merge(others)
          end

          # Check if a object implements the given interface
          def implements?(interface)
            interface = GraphQL.type_map.fetch!(interface, namespaces: namespaces) \
              if interface.is_a?(Symbol)

            all_interfaces.any? { |item| item <= interface }
          end

          # Check if the object definition is valid
          def validate!(*)
            super if defined? super
            all_interfaces.all? { |item| item.validate!(self) }
            nil # No exception already means valid
          end

          private

            # Merge interface fields into the Object's fields,
            # ensuring that only unique fields are added
            def merge_fields(*interfaces)
              interfaces.each do |interface|
                interface.fields.each do |name, field|
                  raise ArgumentError, <<~MSG.squish if field?(name) && fields[name] != field
                    The "#{gql_name}" object already has a "#{field.gql_name}" field and it
                    is not equivalent to the one defined on the "#{interface.gql_name}" interface.
                  MSG

                  proxy_field(field)
                end
              end
            end

          protected

            # A little helper to define arguments using the :arguments key
            def arg(*args, **xargs, &block)
              xargs[:owner] = self
              GraphQL::Argument.new(*args, **xargs, &block)
            end
        end
      end
    end
  end
end
