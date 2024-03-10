# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Import Hidden Directive
    #
    # Indicates that the underlying element is hidden, and should not be
    # available for any request or external usage
    class Directive::HiddenDirective < Directive
      self.hidden = true

      placed_on :scalar, :object, :field_definition, :interface, :union,
        :enum, :input_object, :input_field_definition

      desc <<~DESC
        Marks the underlying element as hidden (internal usage only).
        Hidden elements are not available for any request or external usage.
      DESC

      on(:attach) { |event| event.source.hidden = true }
    end
  end
end
