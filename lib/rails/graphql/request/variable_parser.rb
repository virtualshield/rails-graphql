# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Variable Parser
      #
      # A helper class that works similarly to an GraphQL argument. The process
      # here is to collect provided request args and turn them into operation
      # variables.
      class VariableParser < GraphQL::Argument
        alias reset initialize

        attr_reader :args, :value

        def initialize(operation, args)
          @owner = operation.schema
          @args = args
        end

        # Resolve the given argument by calling +import(data)+, +validate!+, and
        # +export(vars)+.
        def resolve(data, vars)
          import(data)
          validate!
          export(vars)
        end

        # Checks if the argument is valid
        def validate!(*)
          super if defined? super

          raise ArgumentError, <<~MSG.squish unless valid?(value)
            Invalid value "#{value.inspect}" for #{gql_name} argument.
          MSG

          nil # No exception already means valid
        end

        private

          # Import the data the current argument being validated
          def import(data)
            reset(:checker, :string, owner: owner, **data.except(:name, :type))

            @type = data.fetch(:type)
            @gql_name = @name = data.fetch(:name)
            @type_klass = GraphQL.type_map.fetch!(@type, namespaces: owner.namespaces)

            @value = args[gql_name]
            @value = default if @value.nil?
          end

          # Export the argument value to the
          def export(vars)
            vars[name] = to_hash(value) unless value.nil?
          end
      end
    end
  end
end
