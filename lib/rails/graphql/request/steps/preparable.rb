# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper methods for the prepare step of a request
      module Preparable
        # Prepare the object
        def prepare!
          prepare
        rescue => error
          report_exception(error)
        end

        # Marks that the field has prepared data that came outside from the
        # request
        def prepared_data!
          @prepared_data = true
        end

        # Checks if the field has prepared data
        def prepared_data?
          defined?(@prepared_data) && @prepared_data
        end

        protected

          # Normal mode of the prepare step
          def prepare
            prepare_then { prepare_fields }
          end

          # The actual process that prepare the object
          def prepare_then(after_block = nil, &block)
            return if unresolvable?

            stacked do
              block.call if block.present?
              after_block.call if after_block.present?
              trigger_event(:prepared)
            end
          end
      end
    end
  end
end
