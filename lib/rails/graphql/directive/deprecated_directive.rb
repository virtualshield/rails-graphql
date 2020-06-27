# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Directive::DeprecatedDirective < Directive
      self.spec_object = true

      placed_on :field_definition, :enum_value

      desc <<~DESC
        Indicate deprecated portions of a GraphQL service’s schema, such as deprecated
        fields on a type or deprecated enum values.
      DESC

      argument :reason, :string, desc: <<~DESC
        Explain why the underlying element was marked as deprecated. If possible,
        indicate what element should be used instead. This description is formatted
        using Markdown syntax (as specified by [CommonMark](http://commonmark.org/)).
      DESC
    end
  end
end
