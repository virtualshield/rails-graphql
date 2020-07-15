# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQl Multi Query Strategy
      #
      # This is a resolution strategy to solve requests that only contain
      # queries, allowing the strategy to collect all the information for all
      # the queries in a single step before resolving it.
      class Strategy::MultiQueryStrategy < Strategy
        self.priority = 10

        def self.can_resolve?(request) # :nodoc:
          false
          # request.operations.values.all?(&:query?)
        end

        # Executes the strategy in the normal mode
        def resolve!
          response.with_stack(:data) do
            for_each_operation { |op| collect_listeners { op.organize! } }
            for_each_operation(&:prepare!)
            for_each_operation(&:fetch!)
            for_each_operation(&:resolve!)
          end
        end

        # Executes the strategy in the debug mode
        def debug!
          response.with_stack(:data) do
            for_each_operation do |op|
              logger.indented("# Organize phase") do
                collect_listeners { op.debug_organize! }
              end
            end

            for_each_operation do |op|
              logger.indented("# Prepare phase") { op.debug_prepare! }
            end

            for_each_operation do |op|
              logger.indented("# Fetch phase") { op.debug_fetch! }
            end

            for_each_operation do |op|
              logger.indented("# Resolve phase") { op.debug_resolve! }
            end
          end
        end

        private

          # Execute a given block for each defined operation
          def for_each_operation
            operations.each_value { |op| yield op }
          end
      end
    end
  end
end
