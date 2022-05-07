# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Component Typename
      #
      # Extra component which simulates a field that its only purpose is to
      # return the name of the parent GraphQL object
      class Component::Typename < Component
        include ValueWriters
        include Directives

        delegate :operation, to: :parent
        delegate :variables, to: :operation

        parent_memoize :request

        attr_reader :name, :alias_name, :parent

        # Rewrite the kind to always return +:field+
        def self.kind
          :field
        end

        def initialize(parent, node, data)
          @parent = parent

          @name = data[:name]
          @alias_name = data[:alias]

          super(node, data)
        end

        # Set the value that the field will be resolved as
        def resolve_with!(object)
          @typename = object.gql_name
          resolve!
        ensure
          @typename = nil
        end

        # Return the name of the field to be used on the response
        def gql_name
          alias_name || name
        end

        # Write the typename information
        def write_value(value)
          response.serialize(Type::Scalar::StringScalar, gql_name, value)
        end

        # Prepare is not necessary for this field
        def prepare!
        end

        protected

          # Normal mode of the organize step
          def organize
            organize_then
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) { parse_directives(:field) }
          end

          # Go through the right flow to write the value
          def resolve_then
            super do
              typename = @typename || parent.typename
              raise InvalidValueError, (+<<~MSG).squish if typename.blank?
                The #{gql_name} field value cannot be null.
              MSG

              strategy.resolve(self, typename) do |value|
                yield value if block_given?
                trigger_event(:finalize)
              end
            end
          end
      end
    end
  end
end
