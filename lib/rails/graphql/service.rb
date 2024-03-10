# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Service
    #
    # This class allows you to access the features implemented over GraphQL
    # without actually having to send a whole request. The idea is that you can
    # consider GraphQL as your services layer as well. It supports all 3
    # operations (query, mutation, and subscription). You can check if the
    # service was successful by checking the +success?+ method and get the
    # result straight from the return of the operation method, or using
    # +result+. If the operation was not successful, you can check +failure?+
    # and get the error from +error+.
    class Service
    end
  end
end
