# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Strategy
      #
      # This is the base class for the strategies of resolving a request.
      class Strategy
        extend ActiveSupport::Autoload

        autoload :SequencedStrategy
        autoload :MultiQueryStrategy

        # The priority of the strategy
        class_attribute :priority, instance_accessor: false, default: 1

        delegate :operations, :errors, :response, to: :@request

        class << self
          # Check if the strategy can resolve the given +request+. By default,
          # strategies cannot resolve a request. Override this method with a
          # valid checker.
          def can_resolve?(_)
            false
          end
        end

        def initialize(request)
          @request = request
        end

        def resolve!
          raise NotImplementedError
        end

        def debug!
          raise NotImplementedError
        end

        def debugging?
          @debug.present?
        end
      end
    end
  end
end
