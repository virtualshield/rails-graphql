# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # A set of helper methods to write a value to the response
      module ValueWriters
        # Write a value to the response
        def write_value(value)
          writer = 'write_' + field.kind.to_s
          writer = 'write_leaf' unless respond_to?(writer, true)
          send(writer, value)
        end

        # Resolve a given value when it is an array
        def write_array(value, &block)
          write_array!(value) do |item, idx|
            stacked(idx) do
              block.call(item, idx)
              response.next
            rescue StandardError => error
              raise if item.nil?

              block.call(nil, idx)
              response.next

              format_array_execption(error, idx)
              request.exception_to_error(error, @node)
            end
          rescue StandardError => error
            format_array_execption(error, idx)
            raise
          end
        end

        # Helper to start writing as array
        def write_array!(value, &block)
          raise InvalidValueError, <<~MSG.squish unless value.respond_to?(:each)
            The #{gql_name} field is excepting an array
            but got an "#{value.class.name}" instead.
          MSG

          @writing_array = true
          response.with_stack(field.gql_name, array: true, plain: leaf_type?) do
            value.each.with_index(&block)
          end
        ensure
          @writing_array = nil
        end

        # Add the item index to the exception message
        def format_array_execption(error, idx)
          real_error = 'The ' + ActiveSupport::Inflector.ordinalize(idx + 1)
          real_error += " value of the #{gql_name} field"
          source_error = "The #{gql_name} field value"

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
            serializer = response.try(:prefer_string?) ? :to_json : :to_hash
            value = type_klass.public_send(serializer, value.itself)
            response.add(gql_name, value)
          end

          # Trigger the plain field output validation
          def validate_output!(value)
            checker = @writing_array ? :nullable? : :null?
            field&.validate_output!(value, checker: checker, array: false)
          end

        private

          # A problem when an object-based value is not a valid member of the
          # +type_klass+ of this field
          def raise_invalid_member!
            raise(FieldError, <<~MSG.squish)
              The #{gql_name} field result is not a member of #{type_klass.gql_name}.
            MSG
          end
      end
    end
  end
end