# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component Typename
      #
      # Extra component which simulates a field that its only purpose is to
      # return the name of the parent GraphQL object
      class Component::Typename < Component
        include Directives

        delegate :operation, to: :parent

        parent_memoize :request

        attr_reader :name, :alias_name, :parent

        def initialize(parent, node, data)
          @parent = parent

          @name = data[:name]
          @alias_name = data[:alias]

          super(node, data)
        end

        # Return the name of the field to be used on the response
        def gql_name
          alias_name || name
        end

        protected

          # Normal mode of the organize step
          def organize
            organize_then
          end

          # Organize the field in debug mode
          def debug_organize
            display_name = name
            display_name += " as #{alias_name}" if alias_name.present?

            organize_then do
              logger.indented("#{display_name}: Organized!") do
                logger.puts("* Assigned: Dynamic Typename")
                debug_directives
              end
            end

            logger << "#{display_name}: Error! (#{errors.last[:message]})" if invalid?
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) { parse_directives }
          end

          # Write the typename information
          def resolve
            resolve_then { trigger_event(:finalize) }
          end

          # Resolve the field in debug mode
          def debug_resolve(perform = false)
            resolve_then do |value|
              trigger_event(:finalize)
              logger.puts("#{gql_name}: #{value}")
            end
          end

          # Fetch the typename from parent and write on response
          def resolve_then(&block)
            value = parent.typename
            raise InvalidOutputError, <<~MSG.squish if value.blank?
              The #{gql_name} field result cannot be null.
            MSG

            strategy.with_context(item) do |value|
              block.call(value)
              response.add(gql_name, response.try(:prefer_string?) ? value.inspect : value)
            end
          end
      end
    end
  end
end
