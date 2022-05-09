# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQl Cached Strategy
      #
      # This strategy will process hard cached operations. Soft cached
      # operations are those that only the document is cached in the server and
      # processed via its unique identifier (UUID). Whereas, hard cached
      # operations pretty muchy skips the organize step since that is what is
      # cached.
      #
      # Beware, if the version in the cache is different from the version in the
      # type map, it won't be able to process it.
      class Strategy::CachedStrategy < Strategy
        self.priority = 100

        class << self

          # Resolve whenever it has a cache directive on any of the operations
          def can_resolve?(request)
            request.operations.each_value.any? do |op|
              op.data&.directives&.any? { |dir| directive_name(dir) == 'cached' }
            end
          end

          private

            def directive_name(obj)
              Native.node_name(Native.directive_name(obj))
            end
        end

        # Executes the strategy in the normal mode
        def resolve!
          response.with_stack('data') do
            for_each_operation { |op| collect_listeners { op.organize! } }
            for_each_operation { |op| collect_data      { op.prepare!  } }
            for_each_operation { |op| collect_response  { op.resolve!  } }

            # collect_data(true) { op.prepare! }
            # collect_response   { op.resolve! }

            # operations.each_value do |op|
            #   collect_listeners  { op.organize! }
            #   collect_data(true) { op.prepare! }
            #   collect_response   { op.resolve! }
            # end
          end
        end

        private

          # Execute a given block for each defined operation
          def for_each_operation(&block)
            operations.each_value(&block)
          end

      end
    end
  end
end
