# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Alternative Mutation
    #
    # Same as it's parent class, but for mutations
    class Alternative::Mutation < Alternative::Query
      redefine_singleton_method(:type_field_class) { :mutation }
      self.abstract = true

      class << self
        delegate :perform, to: :@field, allow_nil: true
      end
    end
  end
end
