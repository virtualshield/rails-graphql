# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper that contains the main exceptions and validation process for a
      # value against a type
      module WithValidator
        delegate :ordinalize, to: 'ActiveSupport::Inflector'

        protected

          # Run the validation process with +value+ against +type+
          def validate_output!(value, type, checker: :null?, array: true)
            result = validate_null(value, checker)
            result ||= array? && array \
              ? validate_array(value) \
              : validate_type(value) \
              unless value.nil?

            return if result.blank?
            message, idx = result

            base_error = idx.present? \
              ? "#{ordinalize(idx + 1)} value of the #{gql_name} #{type}" \
              : "#{gql_name} #{type} value"

            raise InvalidOutputError, "The #{base_error} #{message}."
          end

        private

          def validate_array(value) # :nodoc:
            return 'is not an array' unless value.is_a?(Enumerable)

            value.each_with_index do |val, idx|
              err = validate_null(val, :nullable?) || validate_type(val)
              return err, idx unless err.nil?
            end
          end

          def validate_null(value, checker = :null?) # :nodoc:
            'can not be null' if value.nil? && !send(checker)
          end

          def validate_type(value) # :nodoc:
            'is invalid' if leaf_type? && !type_klass.valid_output?(value)
          end
      end
    end
  end
end
