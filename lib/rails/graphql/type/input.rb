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
        extend Helpers::WithAssignment
        extend Helpers::WithFields

        setup! kind: :input_object, input: true

        self.field_type = Field::InputField
        self.valid_field_types = [
          Type::Enum,
          Type::Input,
          Type::Scalar,
        ].freeze

        class << self
          # A little override on the name of the object due to the suffix config
          def gql_name
            return @gql_name if defined?(@gql_name)

            suffix = GraphQL.config.auto_suffix_input_objects
            return super if suffix.blank?

            result = super
            result += suffix if result && !result.end_with?(suffix)
            @gql_name = result
          end

          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value = value.to_h if value.respond_to?(:to_h)
            return false unless value.is_a?(Hash)

            fields = enabled_fields
            value = value.transform_keys { |key| key.to_s.camelize(:lower) }
            value = build_defaults.merge(value)

            return false unless value.size.eql?(fields.size)

            fields.all? { |item| item.valid_input?(value[item.gql_name]) }
          end

          # Turn the given value into an isntance of the input object
          def deserialize(value)
            value = value.to_h if value.respond_to?(:to_h)
            value = {} unless value.is_a?(Hash)
            value = enabled_fields.map do |field|
              next unless value.key?(field.gql_name) || value.key?(field.name)
              [field.name, field.deserialize(value[field.gql_name] || value[field.name])]
            end.compact.to_h

            new(OpenStruct.new(value))
          end

          # Build a hash with the default values for each of the given fields
          def build_defaults
            enabled_fields.map { |field| [field.gql_name, field.default] }.to_h
          end

          def inspect # :nodoc:
            args = fields.each_value.map(&:inspect)
            args = args.presence && "(#{args.join(', ')})"
            "#<GraphQL::Input #{gql_name}#{args}>"
          end
        end

        attr_reader :args
        attr_writer :resource

        delegate :fields, to: :class
        delegate :[], to: :args

        delegate_missing_to :resource

        def initialize(args = nil, **xargs)
          @args = args || OpenStruct.new(xargs.transform_keys { |key| key.to_s.underscore })
          @args.freeze

          validate! if args.nil?
        end

        # If the input is assigned to a class, then initialize it with the
        # received arguments. It also accepts extra arguments for inheritance
        # purposes
        def resource(*args, **xargs, &block)
          @resource ||= (klass = safe_assigned_class).nil? ? nil : begin
            xargs = xargs.reverse_merge(params)
            klass.new(*args, **xargs, &block)
          end
        end

        # Just return the arguments as an hash
        def params
          parametrize(self)
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
        end

        private

          # Make sure to turn inputs into params
          def parametrize(input)
            case input
            when Type::Input then parametrize(input.args.to_h)
            when Array       then input.map(&method(:parametrize))
            when Hash        then input.transform_values(&method(:parametrize))
            else input
            end
          end
      end
    end
  end
end
