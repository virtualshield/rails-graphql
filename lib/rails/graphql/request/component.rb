# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component
      #
      # Component is an abstraction of any possible type of object represented
      # by a not of the document of a request. This class helps building
      # cross-component features, like holding event listeners, setting up
      # commom initializer and providing helpers
      class Component
        extend ActiveSupport::Autoload

        include Request::Organizable
        include Request::Prepareable
        include Request::Resolveable

        class << self
          # Return the kind of the component
          def kind
            @kind ||= name.demodulize.underscore.to_sym
          end

          # Helper to memoize results from parent delegation
          def parent_memoize(*methods)
            methods.each do |method_name|
              define_method(method_name) do
                result = parent.public_send(method_name)
                define_singleton_method(method_name) { result }
                result
              end
            end
          end
        end

        attr_reader :data

        delegate :visitor, :response, :strategy, to: :request
        delegate :find_type!, :find_directive!, :trigger_event, to: :strategy
        delegate :memo, :schema, to: :operation
        delegate :kind, to: :class

        alias of_type? is_a?

        eager_autoload do
          autoload :Field
          autoload :Fragment
          autoload :Operation
          autoload :Spread
          autoload :Typename
        end

        def initialize(node, data)
          @node = node
          @data = data
        end

        # Check if the component is in a invalid state
        def invalid?
          defined?(@invalid) && @invalid
        end

        # Mark the component as invalid
        def invalidate!
          @invalid = true
        end

        # Normaly, components are not assignable, only fields are
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
          def capture_exception(stage, invalidate = false)
            yield
          rescue StandardError => error
            invalidate! if invalidate
            stack_path = request.stack_to_path
            stack_path << gql_name if respond_to?(:gql_name) && gql_name.present?
            request.exception_to_error(error, @node, path: stack_path, stage: stage.to_s)
          end
      end
    end
  end
end
