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
        include SelectionSet
        include Directives

        autoload :Query
        autoload :Mutation
        autoload :Subscription

        DATA_PARTS = %i[variables]

        delegate :schema, :visitor, :args, :response, to: :@request
        delegate :kind, :query?, :mutation?, :subscription?, to: :class

        attr_reader :name, :node, :data, :variables, :request

        alias vars variables
        alias gql_name name

        class << self
          # Helper method to initialize an operation given the data
          def build(request, node, data)
            const_get(data[:kind].classify).new(request, node, data)
          end

          # Return the type of the operation
          def kind
            @kind ||= name.demodulize.underscore.to_sym
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
          @data = data.slice(*data_parts)
        end

        # List of necessary parts from data used for preparation step
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        # Prepare the operation by parsing the variables, directives, and the
        # selection set
        def prepare!
          request.stacked(self) do
            do_prepare!
            fields.each_value(&:prepare!)
          rescue StandardError => e
            response.safe_add(name, nil) if name.present?
          end
        end

        # Prepare the operation in debug mode
        def debug_prepare!
          request.stacked(self) do
            do_prepare!

            response.indented("Operation #{kind} #{name || '__default__'}: Prepared!") do
              response.indented("* Variables(#{variables.each_pair.size})") do
                variables.each_pair.with_index do |(k, v), i|
                  response.eol if i > 0
                  response << "#{k}: #{v.inspect}"
                end
              end if variables.each_pair.any?

              debug_directives!
              debug_fields!
            end
          rescue StandardError => e
            response << "Operation #{kind} #{name}: Error! (#{e.message})"
          end
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

          def do_prepare!
            parse_variables!
            parse_directives!
            parse_selection!

            request.trigger_event(:prepare)
          rescue StandardError => e
            request.exception_to_error(e, node, stage: :prepare)
            resolved!
            raise
          ensure
            @data = nil
          end

          def parse_variables!
            @variables = OpenStruct.new

            checker = Request::Argument.new(self, args)
            visitor.collect_variables(*data[:variables]) do |data|
              checker.resolve(data, variables)
            end unless data[:variables].empty?

            @variables.freeze
          end
      end
    end
  end
end
