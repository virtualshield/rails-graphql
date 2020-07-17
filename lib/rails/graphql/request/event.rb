# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Event
      #
      # A small extension of the original event to support extra methods and
      # helpers when performing events during a request
      class Event < GraphQL::Event
        delegate :schema, :errors, :response, :strategy, :logger, to: :request
        delegate :hit, to: :context

        attr_reader :request, :context

        def initialize(*args, request: , context: nil, **xargs, &block)
          super(*args, **xargs, &block)

          @context = context
          @request = request
          @extra.merge!(request: request, context: context)
        end

        # Using the pool of object instances from the strategy, get
        def instance_for(owner)
          strategy.instance_for(owner)
        end
      end
    end
  end
end
