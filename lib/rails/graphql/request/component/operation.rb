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

        # Query is default behavior, so it doesn't need a whole class
        Query = Class.new(self) { redefine_singleton_method(:query?) { true } }

        autoload :Mutation
        autoload :Subscription

        DATA_PARTS = %i[variables]

        delegate :query?, :mutation?, :subscription?, to: :class

        attr_reader :name, :variables, :var_args, :request

        alias vars variables
        alias gql_name name
        alias operation itself

        def initialize(request, node, data)
          @name = data[:name]
          @request = request

          super(node, data)
        end

        # The list of fields comes from the +fields_for+ of the same type as
        # the kind of the operation
        def fields_source
          schema.fields_for(kind)
        end

        # Support memory object to save information across the iteration
        def memo
          @memo ||= OpenStruct.new
        end

        protected

          # Trigger an specific event with the kind of the operation
          def organize
            organize_then do
              trigger_event(kind)
              organize_fields
            end
          end

          # Organize the fragment in debug mode
          def debug_organize
            organize_then do
              logger.indented("#{display_name}: Organized!") do
                yield if block_given?

                debug_variables
                debug_directives
                debug_organize_fields
              end
            end
          rescue StandardError => error
            logger << "#{display_name}: Error! (#{error.message})"
            raise
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              parse_variables
              parse_directives
              parse_selection
            end

            @var_args = nil
          end

          # Set the response key as nil
          def resolve_invalid
            response.safe_add(name, nil) if name.present?
          end

          # Trigger the resolve of the fields
          def resolve(debug = false)
            stacked do
              debug ? debug_resolve_fields : resolve_fields
              trigger_event(:finalize)
            end
          end

          # Display in a YAML format
          def debug_resolve
            return resolve(true) unless name.present?
            logger.indented("#{name}:") { resolve(true) }
          end

        private

          # Name used for debug purposes
          def display_name
            @display_name ||= "#{kind.to_s.titlecase} #{name.presence || '__default__'}"
          end
      end
    end
  end
end
