# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Shared Pagination Field
    #
    # This field integrates with the +@paginate+ directive, allowing one to
    # query the information about a previously initialized pagination.
    class Shared::PaginationField < Alternative::Query
      define_field :pagination, Type::Object::PageInfoObject, null: false

      argument :id, null: false

      desc <<~DESC
        Query the pagination information of a previous setup `@paginate` directive.
        Make sure to provide the same `id` for both parts.
      DESC

      # Validate the pagination and change the calculation of total if needed
      # TODO: Revamp events so that here we can access instance methods
      organized do
        dir = Directive::PaginateDirective.find(request, argument(:id))
        raise ExecutionError, (<<~MSG.squish) unless dir
          The pagination information for the given ID "#{argument(:id)}" was not found.
          Make sure to provide a valid ID and that the field you are paginating has a
          `@paginate` directive with the same ID.
        MSG

        dir.calculate_total = source.selects?(:total, :pages)
      end

      # Get the configured pagination
      def resolve
        Directive::PaginateDirective.find(request, argument(:id))
      end
    end
  end
end
