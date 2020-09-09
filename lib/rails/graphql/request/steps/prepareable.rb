# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper methods for the prepare step of a request
      module Prepareable
        # Prepare the object
        def prepare!
          capture_exception(:prepare) { prepare }
        end

        protected

          # Normal mode of the prepare step
          def prepare
            return if invalid?
            prepare_then { prepare_fields }
          end

          # The actual process that prepare the object
          def prepare_then(after_block = nil, &block)
            return if invalid?
            stacked do
              block.call if block.present?
              trigger_event(:prepared)
              after_block.call if after_block.present?
            end
          end
      end
    end
  end
end
