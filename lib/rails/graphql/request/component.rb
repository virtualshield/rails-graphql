# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Component
      #
      # Component is an abstraction of any possible type of object represented
      # by a not of the document of a request. This class helps building
      # cross-component features, like holding event listeners, setting up
      # common initializer and providing helpers
      class Component
        extend ActiveSupport::Autoload

        include Request::Organizable
        include Request::Preparable
        include Request::Resolvable

        class << self
          # Return the kind of the component
          def kind
            @kind ||= name.demodulize.underscore.to_sym
          end
        end

        delegate :visitor, :response, :strategy, to: :request
        delegate :find_type!, :find_directive!, :trigger_event, to: :strategy
        delegate :memo, :schema, to: :operation
        delegate :kind, to: :class

        alias of_type? is_a?

        eager_autoload do
          autoload :Field
          autoload :Operation
        end

        autoload :Fragment
        autoload :Spread
        autoload :Typename

        def initialize(node)
          @node = node
        end

        # Check if the component is in a invalid state
        def invalid?
          defined?(@invalid) && @invalid
        end

        # Check if the component is marked as skipped
        def skipped?
          defined?(@skipped) && @skipped
        end

        # Just a fancy name for invalid or skipped
        def unresolvable?
          invalid? || skipped?
        end

        # Mark the component as invalid
        def invalidate!
          @invalid = true
        end

        # Skip the component
        def skip!
          @skipped = true
        end

        # Normally, components are not assignable, only fields are
        def assignable?
          false
        end

        protected

          # It's extremely important to have a way to access the current request
          # since not all objects stores a direct pointer to it
          def request
            raise NotImplementedError
          end

          # Use the strategy to set the component into the stack
          def stacked(value = self, &block)
            strategy.stacked(value, &block)
          end

          # Run a given block and ensure to capture exceptions to set them as
          # errors
          def report_exception(error)
            stack_path = request.stack_to_path
            stack_path << gql_name if respond_to?(:gql_name) && gql_name.present?
            request.exception_to_error(error, self, path: stack_path, stage: strategy.stage.to_s)
          end
      end
    end
  end
end
