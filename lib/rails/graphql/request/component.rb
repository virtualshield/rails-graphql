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
          defined?(@invalid) && @invalid.present?
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
        def invalidate!(type = true)
          @invalid = type
        end

        # Skip the component
        def skip!
          @skipped = true
        end

        # Normally, components are not assignable, only fields are
        def assignable?
          false
        end

        # Check if the component can be cached for the response
        def cacheable?
          true
        end

        # Get an identifier of the component
        def hash
          @node.hash
        end

        # Build the cache object
        def cache_dump
          hash = { node: @node }
          hash[:invalid] = @invalid if defined?(@invalid) && @invalid != :authorization
          hash[:skipped] = @skipped if defined?(@skipped) && @skipped
          hash.merge!(super)
          hash
        end

        # Organize from cache data
        def cache_load(data)
          @node = data[:node]
          @invalid = data[:invalid] if data.key?(:invalid)
          @skipped = data[:skipped] if data.key?(:skipped)
          super
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
          def report_exception(error, **extra)
            return if request.rescue_with_handler(error, source: self, **extra) == false

            Backtrace.print(error, self, request)

            extra[:path] = request.stack_to_path
            extra[:path] << gql_name if respond_to?(:gql_name) && gql_name.present?
            request.exception_to_error(error, self, stage: strategy.stage, **extra)
          end

        private

          # Properly transform values to string gid
          def all_to_gid(enum)
            GraphQL.enumerate(enum).each { |item| item.to_gid.to_s }
          end

          # Properly recover values from gid string
          def all_from_gid(enum)
            GraphQL.enumerate(enum).each { |item| GraphQL::GlobalID.find(item) }
          end
      end
    end
  end
end
