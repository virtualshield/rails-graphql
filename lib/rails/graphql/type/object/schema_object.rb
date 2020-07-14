# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # The introspection object for a schema object
      class Object::SchemaObject < Object::AssignedObject
        self.assigned_to = 'Rails::GraphQL::Schema'
        self.spec_object = true

        rename! '__Schema'

        desc <<~DESC
          A GraphQL service’s collective type system capabilities are referred
          to as that service’s "schema". A schema is defined in terms of the
          types and directives it supports as well as the root operation types
          for each kind of operation: query, mutation, and subscription; this
          determines the place in the type system where those operations begin.
        DESC

        field :types,             '__Type',      full: true
        field :query_type,        '__Type',      null: false
        field :mutation_type,     '__Type'
        field :subscription_type, '__Type'
        field :directives,        '__Directive', full: true

        def types
          read_type_map(:Type)
        end

        def directives
          read_type_map(:Directive)
        end

        def query_type
          query_type
        end

        def mutation_type
          mutation_type
        end

        def subscription_type
          subscription_type
        end

        private

          def read_type_map(base_class)
            result = type_map.send(:dig, namespace, base_class).values.map(&:call).uniq
            result += type_map.send(:dig, :base, base_class).values.map(&:call).uniq \
              unless namespace === :base

            result
          end
      end
    end
  end
end
