# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL EnumType
      #
      # Enum types, like scalar types, also represent leaf values in a GraphQL
      # type system. However Enum types describe the set of possible values.
      # See http://spec.graphql.org/June2018/#EnumTypeDefinition
      class Enum < Type
        extend ActiveSupport::Autoload
        extend Helpers::LeafFromAr

        redefine_singleton_method(:leaf_type?) { true }
        redefine_singleton_method(:ar_type) { :enum }
        redefine_singleton_method(:enum?) { true }
        define_singleton_method(:kind) { :enum }
        self.directive_location = :enum
        self.spec_object = true
        self.abstract = true

        eager_autoload do
          autoload :DirectiveLocationEnum
          autoload :TypeKindEnum
        end

        # Define the methods for accessing the values attribute
        inherited_collection :values

        # Define the methods for accessing the description of each enum value
        inherited_collection :value_description, default: {}

        # Define the methods for accessing the directives of each enum value
        inherited_collection :value_directives, default: {}

        class << self
          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value.is_a?(String) && all_values.include?(value)
          end

          # Check if a given value is a valid non-serialized output
          def valid_output?(value)
            value.respond_to?(:to_s) && all_values.include?(value.to_s)
          end

          # Transforms the given value to its representation in a JSON string
          def to_json(value)
            to_hash(value).inspect
          end

          # Transforms the given valye to its representation in a Hash object
          def to_hash(value)
            value.to_s.underscore.upcase
          end

          # Turn a user input of this given type into an ruby object
          def deserialize(value)
            value
          end

          # Use this method to add values to the enum type
          def add(value, desc: nil, directives: nil, deprecated: nil)
            value = to_hash(value)
            raise ArgumentError, <<~MSG if all_values.include?(value)
              The "#{value}" is already defined for #{gql_name} enum.
            MSG

            invalid = directives.try(:any?) { |d| !d.locations.include?(:enum_value) }
            raise ArgumentError, <<~MSG if invalid
              One or more directives provided for "#{value}" can't be used on enum values.
            MSG

            directives = Array.wrap(directives).to_set
            directives << Directive::DeprecatedDirective.new(
              reason: (deprecated.is_a?(String) ? deprecated : nil)
            ) if deprecated.present?

            self.values << value
            self.value_description[value] = desc unless desc.nil?
            self.value_directives[value] = Array.wrap(directives).to_set unless directives.nil?
          end
        end
      end
    end
  end
end
