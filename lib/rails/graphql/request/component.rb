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

        class << self
          # Return the kind of the component
          def kind
            @kind ||= name.demodulize.underscore.to_sym
          end

          # This helps to define functions related to the state of the component
          def define_state(name, bang = nil)
            define_method("#{name}?") { @states.include?(name.to_sym) }
            protected :"#{name}?"

            if bang.present?
              define_method("#{bang}!") { @states << name.to_sym }
              protected :"#{bang}!"
            end
          end
        end

        attr_reader :data

        delegate :schema, :visitor, :errors, :response, :strategy, :logger, to: :request
        delegate :find_type!, :find_directive!, to: :schema
        delegate :kind, to: :class

        define_state :invalid, :invalidate

        eager_autoload do
          autoload :Field
          autoload :Fragment
          autoload :Operation
          autoload :Spread
        end

        def initialize(node, data)
          @node = node
          @data = data.slice(*data_parts)
          @states = Set.new
        end

        protected

          # It's extremely important to have a way to access the current request
          # since not all objects stores s direct pointer to it
          def request
            raise NotImplementedError
          end

          # Use the strategy to set the component into the stack
          def stacked(&block)
            strategy.stacked(self) { block.call }
          end

          # Trigger an event using the strategy, which has better performance
          def trigger_event(*args)
            strategy.trigger_event(*args)
          end

          # List of necessary parts from data in order to process the component
          def data_parts
            klass = self.class
            data_parts = klass.const_defined?(:DATA_PARTS) \
              ? klass.const_get(:DATA_PARTS) \
              : []

            defined?(super) ? data_parts + super : data_parts
          end
      end
    end
  end
end
