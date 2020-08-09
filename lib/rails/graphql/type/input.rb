# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL InputType
      #
      # Input defines a set of input fields; the input fields are either
      # scalars, enums, or other input objects.
      # See http://spec.graphql.org/June2018/#InputObjectTypeDefinition
      class Input < Type
        extend ActiveSupport::Autoload
        extend Helpers::WithFields

        setup! kind: :input_object, input: true

        eager_autoload do
          autoload :ActiveRecordInput
          autoload :AssignedInput
        end

        self.field_types = [Field::InputField].freeze
        self.valid_field_types = [Type::Enum, Type::Input, Type::Scalar].freeze

        class << self
          # A little override on the name of the object due to the suffix config
          def gql_name
            return @gql_name if defined?(@gql_name)

            suffix = GraphQL::Core.auto_suffix_input_objects
            return super if suffix.blank?

            result = super
            result += suffix unless result.end_with?(suffix)
            @gql_name = result
          end

          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value = value.to_h if value.respond_to?(:to_h)
            return false unless value.is_a?(Hash)

            value = build_defaults.merge(value)
            return false unless value.size.eql?(fields.size)

            fields.each_value.all? { |item| item.valid_input?(value[item.gql_name]) }
          end

          # Turn the given value into an isntance of the input object
          def deserialize(value)
            value = value.to_h if value.respond_to?(:to_h)
            value = {} unless value.is_a?(Hash)
            value = build_defaults.merge(value)

            new **fields.transform_values do |field|
              field.deserialize(value[field.gql_name])
            end
          end

          # Build a hash with the default values for each of the given fields
          def build_defaults
            values = fields.each_value.map(&:default)
            fields.values.map(&:gql_name).zip(values).to_h
          end

          # A small helper to turn the input into an input field
          def as_field
            return unless respond_to?(:owner) && owner.present?

            @as_field ||= begin
              field_name = gql_name.delete_sufix('Input').underscore
              Field::InputField.new(field_name, self, owner: owner, desc: description)
            end
          end

          def inspect # :nodoc:
            args = fields.each_value.map(&:inspect)
            args = args.presence && "(#{args.join(', ')})"
            "#<GraphQL::Input #{gql_name}#{args}>"
          end
        end

        attr_reader :args

        delegate_missing_to :args

        def initialize(args = nil, **xargs)
          @args = args || OpenStruct.new(xargs.transform_keys { |key| key.to_s.underscore })
          @args.freeze

          validate! if args.nil?
        end

        # Checks if all the values provided to the input instance are valid
        def validate!(*)
          errors = []
          fields.each do |name, field|
            field.validate_output!(@args[name.to_s])
          rescue InvalidValueError => error
            errors << error.message
          end

          return if errors.empty?
          raise InvalidValueError, <<~MSG.squish
            Invalid value provided to #{gql_name} field: #{errors.to_sentence}.
          MSG

          nil # No exception already means valid
        end
      end
    end
  end
end
