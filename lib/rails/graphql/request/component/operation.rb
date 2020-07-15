# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component Operation
      #
      # This class holds information about a given operation. This will guide
      # the validation and execution of it.
      class Component::Operation < Component
        extend ActiveSupport::Autoload

        include SelectionSet
        include Directives

        class << self
          # Helper method to initialize an operation given the data
          def build(request, node, data)
            const_get(data[:kind].classify).new(request, node, data)
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

        DATA_PARTS = %i[variables]

        delegate :query?, :mutation?, :subscription?, to: :class

        attr_reader :name, :variables, :request

        alias vars variables
        alias gql_name name
        alias operation itself

        autoload :Query
        autoload :Mutation
        autoload :Subscription

        def initialize(request, node, data)
          super(node, data)

          @name = data[:name]
          @request = request
        end

        # The list of fields comes from the +fields_for+ of the same type as
        # the kind of the operation
        def fields_source
          schema.fields_for(kind)
        end

        protected

          # Set the response key as nil
          def invalidate!
            response.safe_add(name, nil) if name.present?
            super
          end

          # Organize the fragment in debug mode
          def debug_organize
            display_name = kind.to_s.titlecase
            display_name += ' ' + (name.presence || '__default__')

            organize_then do
              logger.indented("#{display_name}: Organized!") do
                debug_variables
                debug_directives
                debug_organize_fields
              end
            end

            logger << "#{display_name}: Error! (#{errors.last[:message]})" if invalid?
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              parse_variables
              parse_directives
              parse_selection
            end
          end
      end
    end
  end
end
