# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper methods for the resolve step of a request
      module Resolveable
        # When the +type_klass+ of an object is an interface or a union, the
        # field needs to be redirected to the one from the actual resolved
        # +object+ type
        def resolve_with!(object)
          return resolve! if invalid?
          capture_exception(:resolve) do
            old_field, @field, @tmp_klass = @field, object[@field.name], object

            resolve
          ensure
            @field, @tmp_klass = old_field, nil
          end
        end

        # Resolve the object
        def resolve!
          capture_exception(:resolve) { resolve }
        end

        # Resolve a given value when it's an array
        def resolve_with_array!(value, &block)
          response.with_stack(field.gql_name, array: true, plain: leaf_type?) do
            current.each_with_index do |item, idx|
              block.call(item, idx)
            rescue StandardError => e
              real_error = ActiveSupport::Inflector.ordinalize(idx)
              real_error += " result of the #{gql_name} field"
              source_error = "The #{gql_name} field result"

              e.message.gsub!(source_error, real_error)
              raise
            end
          end
        end

        # Write a value to the response
        def write_value(value)
          writer = 'write_' + field.kind.to_s
          writer = 'write_leaf' unless respond_to?(writer, true)
          send(writer, item)
        end

        protected

          # Normal mode of the resolve step
          def resolve
            return try(:resolve_invalid) if invalid?
            resolve_then { resolve_fields }
          end

          # The actual process that resolve the object
          def resolve_then(after_block, &block)
            return if invalid?
            stacked do
              block.call
              trigger_event(:finalize)
              after_block.call if after_block.present?
            end
          end

          # Write a value based on a Union type
          def write_union(value)
            object = type_klass.all_members.reverse_each.find { |t| t.valid_member?(value) }
            object.nil? ? raise_invalid_member! : write_object(value, object)
          end

          # Write a value based on a Interface type
          def write_interface(value)
            object = type_klass.all_types.reverse_each.find { |t| t.valid_member?(value) }
            object.nil? ? raise_invalid_member! : write_object(value, object)
          end

          # Write a value based on a Object type
          def write_object(value, object = nil)
            object ||= type_klass.valid_member?(value) ? type_klass : raise_invalid_member!
            selection.each_value { |field| field.resolve_with!(object) }
          end

          # Write a value with the correct serialize mode. Validate the output
          # but do not use array mode because this method will be called
          # multiple times inside of an array.
          def write_leaf(value)
            validate_output!(value)
            serializer = response.try(:prefer_string?) ? :to_json : :to_hash
            response.add(gql_name, type_klass.public_send(serializer, value))
          end

          # Trigger the plain field output validation
          def validate_output!(value)
            field&.validate_output!(value, array: false)
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
