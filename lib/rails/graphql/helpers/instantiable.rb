# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # This marks an object as instantiable during a requesting, which means it
      # will be associated with an event and most of it's information comes from
      # the running event.
      module Instantiable
        delegate_missing_to :event
        attr_reader :event
      end
    end
  end
end
