# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The introspection object for a schema object
      class Object::SchemaObject < Object
        self.assigned_to = 'Rails::GraphQL::Schema'
        self.spec_object = true

        rename! '__Schema'

        desc <<~DESC
          A GraphQL service's collective type system capabilities are referred
          to as that service's "schema". A schema is defined in terms of the
          types and directives it supports as well as the root operation types
          for each kind of operation: query, mutation, and subscription; this
          determines the place in the type system where those operations begin.
        DESC

        field :types,             '__Type',      full: true, method_name: :read_types
        field :query_type,        '__Type',      null: false
        field :mutation_type,     '__Type'
        field :subscription_type, '__Type'
        field :directives,        '__Directive', full: true, method_name: :read_directives

        # TODO: make it work for lazy enumerator
        def read_types
          event.schema.types(base_class: :Type).force
        end

        # TODO: it only works after eager_load!
        def read_directives
          Directive.eager_load!
          event.schema.types(base_class: :Directive).force
        end
      end
    end
  end
end
