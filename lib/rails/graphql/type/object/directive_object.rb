# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The introspection object for directives
      class Object::DirectiveObject < Object
        self.assigned_to = 'Rails::GraphQL::Directive'
        self.spec_object = true

        rename! '__Directive'

        desc <<~DESC
          Directives provide a way to describe alternate runtime execution
          and type validation behavior in a GraphQL document.

          In some cases, you need to provide options to alter GraphQL’s execution
          behavior in ways field arguments will not suffice, such as conditionally
          including or skipping a field. Directives provide this by describing
          additional information to the executor.
        DESC

        field :name,        :string,               null: false, method_name: :gql_name
        field :description, :string
        field :locations,   '__DirectiveLocation', full: true
        field :args,        '__InputValue',        full: true

        def args
          all_arguments.values
        end
      end
    end
  end
end
