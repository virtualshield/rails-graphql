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

      on :organize do |event|
        report_for_field(event)
      end

      on :finalize, for: Type::Enum do |event|
        report_for_enum_value(event)
      end

      private

        # Check if the event field
        def report_for_field(event)
          return unless event.field.using?(self.class)
          item = "#{event.source.gql_name} field"
          event.request.report_error(build_message(item))
        end

        def report_for_enum_value(event)
          return unless event.field.type_klass.value_using?(event.current_value, self.class)
          value = event.field.type_klass.to_hash(event.current_value)
          item = "#{value} value for the #{event.source.gql_name} field"
          event.request.report_error(build_message(item))
        end

        def build_message(item)
          result = "The #{item} is deprecated"
          result += ", reason: #{args.reason}" if args.reason.present?
          result + '.'
        end
    end
  end
end
