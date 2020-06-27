# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Argument
      #
      # A little different from the normal argument, since the focus of this
      # class is to validate and import arquments from the request.
      class Argument < GraphQL::Argument
        alias import initialize

        attr_reader :args, :value

        def initialize(owner, args)
          @owner = owner
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
            The given value "#{default.inspect}" is not valid for this argument.
          MSG

          nil # No exception already means valid
        end

        private

          # Import the data the current argument being validated
          def import(data)
            name = data.delete(:name)
            type = data.delete(:type)
            super(name, type, owner: owner, **data)

            @value = args[gql_name] || default
          end

          # Export the argument value to the
          def export(vars)
            vars[name] = to_hash(value) unless value.nil?
          end
      end
    end
  end
end
