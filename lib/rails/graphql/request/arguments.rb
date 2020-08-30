# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
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
        LAZY_LOADER = ->(key, object) { object.variables[key] }.curry

        delegate :key?, to: :@table

        class << self
          # Easy access to the easy loader method
          def lazy
            LAZY_LOADER
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

          # If it's running under a scope, transform proc based values
          def transform(value)
            return if value.nil?
            scoped? && value.is_a?(Proc) ? value.call(operation) : value
          end
        end

        # Transform any proc by its actual value before returning the hash
        def to_h(*)
          super.transform_values(&self.class.method(:transform))
        end

        # Before iterating, transform any needed value
        def each_pair
          enum = to_h.to_enum
          return enum unless block_given?
          enum.each { |v| yield v }
          self
        end

        # Transform the value before returning
        def method_missing(*)
          self.class.transform(super)
        end

        # Transform the value before returning
        def [](*)
          self.class.transform(super)
        end

        # Transform the value before returning
        def dig(name, *names)
          result = self.class.transform(super(name))
          names.empty? ? result : result&.dig(*names)
        end

        # Override the freeze method to just freeze the table and do not create
        # the getters and setter methods
        def freeze
          @table.freeze
          super
        end
      end
    end
  end
end
