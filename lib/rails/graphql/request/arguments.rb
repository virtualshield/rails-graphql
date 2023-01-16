# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Arguments
      #
      # This is an extension of an +OpenStruct+ since argument values can be
      # assigned a Proc, which means that in order to collect their value, we
      # need to rely on the current operation being processed.
      #
      # They lazy variable-based value is used for fragments, so that they can
      # be organized only once and have their variables changed accordingly to
      # the spread and operation.
      class Arguments < OpenStruct
        THREAD_KEY = :_rails_graphql_operation

        class Lazy < Delegator
          attr_reader :var_name

          def self.[](key)
            new(key)
          end

          def initialize(var_name)
            @var_name = var_name
          end

          def __getobj__
            Arguments.operation&.variables&.dig(var_name)
          end

          def __setobj__(*)
            raise FrozenError
          end
        end

        delegate :key?, to: :@table

        class << self
          # Easy access to the easy loader method
          def lazy
            Lazy
          end

          # Get the current operation thread safely
          def operation
            Thread.current[THREAD_KEY]
          end

          # Execute a block inside a scoped thread-safe arguments
          def scoped(value)
            old_value, Thread.current[THREAD_KEY] = operation, value

            yield
          ensure
            Thread.current[THREAD_KEY] = old_value
          end

          # Check if it's performing inside a scoped value
          def scoped?
            operation.present?
          end
        end
      end
    end
  end
end
