# frozen_string_literal: true

module Rails
  module GraphQL
    module Native
      def self.attach_operation(method_name, function_name, result: :string)
        attach_function(method_name, function_name, [:pointer], result)
      end

      attach_operation :operation_type, :GraphQLAstOperationDefinition_get_operation
      attach_operation :node_name,      :GraphQLAstName_get_value

      attach_operation :get_int_value,    :GraphQLAstIntValue_get_value
      attach_operation :get_float_value,  :GraphQLAstFloatValue_get_value
      attach_operation :get_string_value, :GraphQLAstStringValue_get_value
      attach_operation :get_enum_value,   :GraphQLAstEnumValue_get_value

      with_options(result: :pointer) do
        attach_operation :default_value, :GraphQLAstVariableDefinition_get_default_value
        attach_operation :type_name,     :GraphQLAstNamedType_get_name

        attach_operation :argument_name,  :GraphQLAstArgument_get_name
        attach_operation :argument_value, :GraphQLAstArgument_get_value

        attach_operation :ofield_name,  :GraphQLAstObjectField_get_name
        attach_operation :ofield_value, :GraphQLAstObjectField_get_value

        attach_operation :variable_name, :GraphQLAstVariable_get_name
      end

      with_options(result: :int) do
        attach_operation :list_size, :GraphQLAstListValue_get_values_size

        attach_operation :get_boolean_value, :GraphQLAstBooleanValue_get_value
      end
    end
  end
end
