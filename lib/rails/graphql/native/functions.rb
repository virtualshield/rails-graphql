# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      def self.attach_operation(method_name, function_name, result = :string)
        attach_function(method_name, function_name, [:pointer], result)
      end

      attach_operation :operation_type, :GraphQLAstOperationDefinition_get_operation
      attach_operation :fragment_name,  :GraphQLAstFragmentDefinition_get_name, :pointer
      attach_operation :node_name,      :GraphQLAstName_get_value
    end
  end
end
