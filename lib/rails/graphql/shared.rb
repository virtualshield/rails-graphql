# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Shared
    #
    # A series of shared elements designed to be used whenever a developer
    # sett that fits their application design.
    module Shared
      extend ActiveSupport::Autoload

      autoload :PaginationField
    end
  end
end
