# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Schema
    #
    class Schema
      include Core
    end

    ActiveSupport.run_load_hooks(:graphql, Schema)
  end
end
