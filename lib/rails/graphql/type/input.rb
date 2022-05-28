# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
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

          # Transforms the given value to its representation in a JSON string
          def as_json(value)
            parse_arguments(value, using: :as_json, key: :gql_name)
          end

          # Transforms the given value to its representation in a Hash object
          def to_json(value)
            as_json(value).to_json
          end

          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value = JSON.parse(value) if valid_token?(value, :hash)
            value = value.to_h if value.respond_to?(:to_h)
            return false unless value.is_a?(Hash)

            fields = enabled_fields
            value = value.transform_keys { |key| key.to_s.camelize(:lower) }
            value = build_defaults.merge(value)

            return false unless value.size.eql?(fields&.count || 0)

            fields&.all? { |item| item.valid_input?(value[item.gql_name]) }
          end

          # Turn the given value into an isntance of the input object
          def deserialize(value)
            new(OpenStruct.new(parse_arguments(value, using: :deserialize)))
          end

          alias build deserialize

          # Build a hash with the default values for each of the given fields
          def build_defaults
            return {} unless fields?
            enabled_fields.each.with_object({}) do |field, hash|
              hash[field.gql_name] = field.default
            end
          end

          def inspect
            return super if self.eql?(Type::Input)
            args = fields.values.map(&:inspect)
            args = args.presence && +"(#{args.join(', ')})"

            directives = inspect_directives
            directives.prepend(' ') if directives.present?
            +"#<GraphQL::Input #{gql_name}#{args}#{directives}>"
          end

          private

            def parse_arguments(value, using:, key: :name)
              value = JSON.parse(value) if valid_token?(value, :hash)
              value = value.to_h if value.respond_to?(:to_h)
              value = {} unless value.is_a?(Hash)
              value = value.stringify_keys

              enabled_fields.each.with_object({}) do |field, hash|
                next unless value.key?(field.gql_name) || value.key?(field.name.to_s)
                result = value[field.gql_name] || value[field.name.to_s]
                hash[field.public_send(key)] = field.public_send(using, result)
              end.compact
            end
        end

        attr_reader :args
        attr_writer :resource

        delegate :fields, to: :class
        delegate :to_h, :[], to: :args

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

        # Corretly turn all the arguments into their +as_json+ version and
        # return a hash of them
        def args_as_json
          self.class.as_json(@args.to_h)
        end

        # Corretly turn all the arguments into their +to_json+ version and
        # return a hash of them
        def args_to_json
          self.class.to_json(@args.to_h)
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
          raise InvalidValueError, (+<<~MSG).squish
            Invalid value provided to #{gql_name} field: #{errors.to_sentence}.
          MSG
        end

        %i[to_global_id to_gid to_gid_param].each do |method_name|
          define_method(method_name) do
            self.class.public_send(method_name, args_as_json.compact)
          end
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
