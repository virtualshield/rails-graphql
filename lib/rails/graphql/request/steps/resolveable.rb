# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper methods for the resolve step of a request
      module Resolveable
        # Resolve the object if it is not invalid
        def resolve!
          capture_exception(:resolve) { invalid? ? resolve_invalid : resolve }
        end

        # Resolve the object in debug mode
        def debug_resolve!
          capture_exception(:resolve) { invalid? ? debug_resolve_invalid : debug_resolve }
        end

        protected

          # Normal mode of the resolve step
          def resolve
            raise NotImplementedError
          end

          # Debug mode of the resolve step
          def debug_resolve
            raise NotImplementedError
          end

          # Originally this methods just perform the same as the non-debug one
          def debug_resolve_invalid
            resolve_invalid
          end
      end
    end
  end
end
