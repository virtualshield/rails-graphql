# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Cached Directive
    #
    # Indicates that the request has hard cached operations that need to be
    # collected
    class Directive::CachedDirective < Directive
      placed_on :query

      desc 'Indicates that there are hard cached operations.'

      argument :id, :ID, null: false, desc: <<~DESC
        The unique identifier of the cached operation.
      DESC

      on(:attach) do |source, request|
        source.data.selection = nil
        # TODO: Add the request name back
        # source.instance_variable_set(:@name, 'here')

        # TODO: Add the arguments and variables
        field = request.build(Request::Component::Field, source, nil, { name: 'a', alias: 'b' })
        field.assing_to(ApplicationSchema[:query][:a])
        field.check_authorization!

        source.instance_variable_set(:@selection, { 'b' => field })
        # puts source.inspect
      end
    end
  end
end
