# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module GraphiQL
      ##
      # :singleton-method:
      # Marks if this gem will be providing a route with a GraphiQL interface.
      mattr_accessor :enabled, instance_writer: false, default: false
    end
  end
end
