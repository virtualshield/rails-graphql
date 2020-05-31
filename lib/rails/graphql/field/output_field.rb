# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Field::OutputField < Field
      redefine_singleton_method(:output_type?) { true }
    end
  end
end
