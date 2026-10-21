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

          # Transforms the given value to its representation in a Hash object
          def as_json(value)
            parse_arguments(value, using: :as_json, key: :gql_name)
          end

          # Transforms the given value to its representation in a JSON string
          def to_json(value)
            as_json(value).to_json
          end

          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value = as_json(value) if value.is_a?(Type::Input)
            value = GraphQL.config.literal_input_parser.call(value) \
              if valid_token?(value, :hash)

            return false if value.is_a?(::Array) || valid_token?(value, :array)
            value = value.to_h if value.respond_to?(:to_h)
            return false unless value.is_a?(::Hash)

            fields = enabled_fields
            names = fields&.each&.with_object({}) do |field, hash|
              hash[field.gql_name] = hash[field.name.to_s] = field.gql_name
            end

            converted = value.transform_keys { |key| names&.fetch(key.to_s, key) || key }
            return false unless converted.size.eql?(value.size)

            value = build_defaults.merge(converted)

            return false unless value.size.eql?(fields&.count || 0)

            fields&.all? { |item| item.valid_input?(value[item.gql_name]) }
          end

          # Turn the given value into an instance of the input object. A field
          # missing from the value takes its default and is listed in the
          # instance's +defaulted_fields+; an explicit null stays null
          def deserialize(value = nil, **value_as_hash)
            value = value_as_hash if value.nil?
            defaulted = []
            args = parse_arguments(value, using: :deserialize) { |field| defaulted << field.name.to_sym }
            new(OpenStruct.new(args)).tap do |input|
              input.instance_variable_set(:@defaulted_fields, defaulted.freeze)
            end
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

            # An instance is read by its provided fields only, and deserializing
            # one copies those values as they are
            def parse_arguments(value, using:, key: :name)
              copy = value.is_a?(Type::Input) && using == :deserialize
              value = input_values(value)

              enabled_fields.each.with_object({}) do |field, hash|
                if value.key?(field.gql_name) || value.key?(field.name.to_s)
                  result = value[field.gql_name]
                  result = value[field.name.to_s] if result.nil?
                  result = field.public_send(using, result) unless result.nil? || copy
                  hash[field.public_send(key)] = result
                elsif using == :deserialize && field.default_value?
                  hash[field.public_send(key)] = default_value_for(field)
                  yield field if block_given?
                end
              end
            end

            def input_values(value)
              return value.provided_values.stringify_keys if value.is_a?(Type::Input)

              value = GraphQL.config.literal_input_parser.call(value) \
                if valid_token?(value, :hash)

              value = value.to_h if value.respond_to?(:to_h)
              value = {} unless value.is_a?(::Hash)
              value.stringify_keys
            end

            # The declared default in its deserialized form, never the schema's
            # own object
            def default_value_for(field)
              field.deserialize(field.default).deep_dup
            end
        end

        # +defaulted_fields+ lists the fields that took their declared default
        # instead of a given value
        attr_reader :args, :assignment_error, :defaulted_fields
        attr_writer :resource

        delegate :fields, to: :class
        delegate :to_h, :[], to: :args

        delegate_missing_to :resource

        def initialize(args = nil, **xargs)
          @defaulted_fields = EMPTY_ARRAY
          @args = args || build_ostruct(xargs)
          @args.freeze

          validate! if args.nil?
        end

        # If the input is assigned to a class, then initialize it with the
        # received arguments. It also accepts extra arguments for inheritance
        # purposes. The attributes come from the +params+ of a copy of this
        # instance that counts every value as provided, so the declared
        # defaults go through any +params+ override while this instance's own
        # +params+ keeps answering the provided fields
        def resource(*args, **xargs, &block)
          return @resource if defined?(@resource)
          return if (klass = safe_assigned_class).nil?

          @resource = begin
            companion = dup
            companion.instance_variable_set(:@defaulted_fields, EMPTY_ARRAY)
            xargs = xargs.reverse_merge(companion.params)
            klass.new(*args, **xargs, &block)
          end
        end

        # Return the provided arguments as a hash, without the fields that took
        # their declared default
        def params
          parametrize(provided_values)
        end

        # Correctly turn all the provided arguments into their +as_json+
        # version and return a hash of them
        def args_as_json
          self.class.as_json(self)
        end

        alias as_json args_as_json

        # Correctly turn all the provided arguments into their +to_json+
        # version and return a JSON string of them
        def args_to_json
          self.class.to_json(self)
        end

        alias to_json args_to_json

        # Checks if all the values provided to the input instance are valid
        def validate!(*)
          errors = []
          fields.each do |name, field|
            field.validate_output!(@args[name.to_s])
          rescue InvalidValueError => error
            errors << error.message
          end

          return if errors.empty?
          errors = errors.map { |message| message.delete_suffix('.') }.to_sentence
          raise InvalidValueError, (+<<~MSG).squish
            Invalid value provided to #{self.class.gql_name} field: #{errors}.
          MSG
        end

        # Override this method to save any errors that could happen with loading
        # the assigned class
        def safe_assigned_class
          assigned_class
        rescue ::ArgumentError, ::NameError => error
          @assignment_error = error
          nil
        end

        %i[to_global_id to_gid to_gid_param].each do |method_name|
          define_method(method_name) do
            self.class.public_send(method_name, GraphQL.deep_compact(args_as_json))
          end
        end

        # The values the input was given, explicit nulls included
        def provided_values
          @args.to_h.except(*defaulted_fields)
        end

        protected

          # A helper to turn a hash into a proper OpenStruct instance
          def build_ostruct(hash)
            OpenStruct.new(hash.transform_keys { |key| key.to_s.underscore })
          end

        private

          # Make sure to turn inputs into params
          def parametrize(input)
            case input
            when Type::Input then input.params
            when Array       then input.map(&method(:parametrize))
            when Hash        then input.transform_values(&method(:parametrize))
            else input
            end
          end
      end
    end
  end
end
