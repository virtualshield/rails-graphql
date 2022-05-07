# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module that is a different implementation of the
      # +GlobalID::Identification+, but instead of things being found by the
      # class that they are, it uses owners and base classes.
      module WithGlobalID
        def to_global_id(options = nil)  # :nodoc:
          GlobalID.create(self, options)
        end

        alias to_gid to_global_id

        def to_gid_param(options = nil)  # :nodoc:
          to_global_id(options).to_param
        end
      end
    end
  end
end
