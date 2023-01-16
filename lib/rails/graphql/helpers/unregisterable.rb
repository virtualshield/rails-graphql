# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper that allows unregisterable objects to be both identified and
      # removed from type map
      module Unregisterable
        # Simply remove itself from the type map
        def unregister!
          GraphQL.type_map.unregister(self)
        end
      end
    end
  end
end
