# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Bigint basically removes the limit of the value, but it serializes as
      # a string so it won't go against the spec
      class Enum::PaginationModeEnum < Enum
        rename! '_PaginationMode'

        desc <<~DESC
          The type of pagination that should be used when attaching a
          `@paginate` directive to a field.
        DESC

        add 'PAGES', desc: 'The `current` is the page number to be displayed'

        add 'OFFSET', desc: 'The `current` is the offset to be used in the query'

        add 'KEYSET', desc: 'The `current` is the last id to be used in the query'
      end
    end
  end
end
