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

      on :organized do |event|
        report_for_field(event)
      end

      on :finalize, for: Type::Enum do |event|
        report_for_enum_value(event)
      end

      private

        # Check if the requested field is marked as deprecated
        def report_for_field(event)
          return unless event.field.using?(self.class)
          item = "#{event.source.gql_name} field"
          event.request.report_error(build_message(item))
        end

        # Check if the resolved enum value is marked as deprecated
        def report_for_enum_value(event)
          return unless event.current_value.deprecated?

          value = event.current_value.to_s
          item = "#{value} value for the #{event.source.gql_name} field"
          event.request.report_error(build_message(item))
        end

        # Build the error message to display on the result
        def build_message(item)
          result = "The #{item} is deprecated"
          result += ", reason: #{args.reason}" if args.reason.present?
          result + '.'
        end
    end
  end
end
