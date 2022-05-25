# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # A set of helper methods to write a value to the response
      module ValueWriters
        # TODO: Maybe move this to a setting so it allow extensions
        KIND_WRITERS = {
          union:     :write_union,
          interface: :write_interface,
          object:    :write_object,
        }.freeze

        # Write a value to the response
        def write_value(value)
          return write_leaf(value) if value.nil?
          send(KIND_WRITERS[field.kind] || :write_leaf, value)
        end

        # Resolve a given value when it is an array
        def write_array(value, idx = -1, &block)
          write_array!(value) do |item|
            stacked(idx += 1) do
              block.call(item, idx)
              response.next
            rescue StandardError => error
              raise if item.nil?

              block.call(nil, idx)
              response.next

              format_array_execption(error, idx)
              request.exception_to_error(error, self)
            end
          rescue StandardError => error
            format_array_execption(error, idx)
            raise
          end
        end

        # Helper to start writing as array
        def write_array!(value, &block)
          raise InvalidValueError, (+<<~MSG).squish unless value.respond_to?(:each)
            The #{gql_name} field is excepting an array
            but got an "#{value.class.name}" instead.
          MSG

          @writing_array = true
          response.with_stack(gql_name, array: true, plain: leaf_type?) do
            value.each(&block)
          end
        ensure
          @writing_array = nil
        end

        # Add the item index to the exception message
        def format_array_execption(error, idx)
          real_error = (+<<~MSG).squish
            The #{ActiveSupport::Inflector.ordinalize(idx + 1)} value of the #{gql_name} field
          MSG

          source_error = +"The #{gql_name} field value"

          message = error.message.gsub(source_error, real_error)
          error.define_singleton_method(:message) { message }
        end

        protected

          # Write a value based on a Union type
          def write_union(value)
            object = type_klass.all_members.reverse_each.find { |t| t.valid_member?(value) }
            object.nil? ? raise_invalid_member! : resolve_fields(object)
          end

          # Write a value based on a Interface type
          def write_interface(value)
            object = type_klass.all_types.reverse_each.find { |t| t.valid_member?(value) }
            object.nil? ? raise_invalid_member! : resolve_fields(object)
          end

          # Write a value based on a Object type
          def write_object(value)
            type_klass.valid_member?(value) ? resolve_fields : raise_invalid_member!
          end

          # Write a value with the correct serialize mode. Validate the output
          # but do not use array mode because this method will be called
          # multiple times inside of an array.
          def write_leaf(value)
            validate_output!(value)
            return response.safe_add(gql_name, nil) if value.nil?

            # Necessary call #itself to loose the dynamic reference
            response.serialize(type_klass, gql_name, value.itself)
          end

          # Trigger the plain field output validation
          def validate_output!(value)
            checker = defined?(@writing_array) && @writing_array ? :nullable? : :null?
            field&.validate_output!(value, checker: checker, array: false)
          end

        private

          # A problem when an object-based value is not a valid member of the
          # +type_klass+ of this field
          def raise_invalid_member!
            raise FieldError, (+<<~MSG).squish
              The #{gql_name} field result is not a member of #{type_klass.gql_name}.
            MSG
          end
      end
    end
  end
end
