# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper methods for the resolve step of a request
      module Resolveable
        # Resolve the object
        def resolve!
          capture_exception(:resolve) { resolve }
        end

        protected

          # Normal mode of the resolve step
          def resolve
            invalid? ? try(:resolve_invalid) : resolve_then
          end

          # The actual process that resolve the object
          def resolve_then(after_block = nil, &block)
            return if invalid?
            stacked do
              block.call if block.present?
              trigger_event(:finalize)
              after_block.call if after_block.present?
            end
          end
      end
    end
  end
end
