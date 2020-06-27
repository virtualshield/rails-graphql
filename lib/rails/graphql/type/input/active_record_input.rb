# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL Active Record Input
      #
      # The base class for any +ActiveRecord::Base+ class represented as an
      # GraphQL input type
      class Input::ActiveRecordInput < Input::AssignedInput
        self.abstract = true
      end
    end
  end
end
