# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Operation
      #
      # This class holds information about a given operation. This will guide
      # the validation and execution of it.
      class Operation
        extend ActiveSupport::Autoload

        autoload :Query
        autoload :Mutation
        autoload :Subscription

        delegate :memo, :schema, :visitor, :fragments, :errors, :args, :response, to: :@request
        delegate :kind, :query?, :mutation?, :subscription?, to: :class

        attr_reader :name, :node, :data, :variables, :directives, :request

        alias vars variables
        alias gql_name name

        class << self
          # Return the type of the operation
          def kind
            @kind ||= demodulize.underscore.to_sym
          end

          # Defines if the current operation is a query type
          def query?
            false
          end

          # Defines if the current operation is a mutation type
          def mutation?
            false
          end

          # Defines if the current operation is a subscription type
          def subscription?
            false
          end
        end

        def initialize(request, node, data)
          @request = request
          @node = node
          @name = data[:name]
          @data = data.slice(:directives, :selection, :variables)
        end

        # Prepare the operation by parsing the variables, directives, and the
        # selection set
        def prepare!
          request.stacked(self) do
            parse_variables!
            parse_directives!
            # parse_selection!

            request.trigger_event(:prepare)
          rescue StandardError => e
            request.exception_to_error(e, node, stage: :prepare)
            response.safe_add(name, nil) if name.present?
            resolved!
          end

          @directives&.freeze
          @variables&.freeze
          @data = nil
        end

        # Check if the operation was already resolved
        def resolved?
          @resolved.present?
        end

        # Mark the operation as resolved
        def resolved!
          @resolved = true
        end

        private

          def parse_variables!
            @variables = OpenStruct.new
            return if data[:variables].empty?

            checker = Request::Argument.new(self, args)
            visitor.collect_variables(*data[:variables]) do |data|
              checker.resolve(data, variables)
            end
          end

          def parse_directives!
            @directives = []
            return if data[:directives].empty?

            event = GraphQL::Event.new(:attach, self, :execution)
            visitor.collect_directives(*data[:directives]) do |data|
              item = GraphQL.type_map.fetch!(
                data[:name],
                base_class: :Directive,
                namespaces: schema.namespaces,
              ).new(**data[:arguments])

              event.trigger_for(item)
              directives << item
            end
          end
      end
    end
  end
end
