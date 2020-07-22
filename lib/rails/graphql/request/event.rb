# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Event
      #
      # A small extension of the original event to support extra methods and
      # helpers when performing events during a request
      class Event < GraphQL::Event
        def self.trigger(objects, event_name, strategy, **extra)

        end

      end
    end
  end
end
