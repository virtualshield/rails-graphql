# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper methods for the resolve step of a request
      module Resolvable
        # Resolve the object
        def resolve!
          resolve
        rescue => error
          report_exception(error)
        end

        protected

          # Normal mode of the resolve step
          def resolve
            return if skipped?
            invalid? ? try(:resolve_invalid) : resolve_then
          rescue
            try(:resolve_invalid)
            raise
          end

          # The actual process that resolve the object
          def resolve_then(after_block = nil, &block)
            return if unresolvable?

            stacked do
              block&.call
              after_block&.call
              trigger_event(:finalize)
            end
          end
      end
    end
  end
end
