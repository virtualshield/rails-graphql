# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component Fragment
      #
      # This class holds information about a given fragment defined using the
      # +fragment+ statement during an execution. This will guide the validation
      # and execution of it.
      class Component::Fragment < Component
        include SelectionSet
        include Directives

        DATA_PARTS = %i[type]

        attr_reader :name, :type_klass, :request

        def initialize(request, node, data)
          @name = data[:name]
          @request = request

          super(node, data)
        end

        # Return a lazy loaded variable proc
        def variables
          Request::Arguments.lazy
        end

        # Access the operation through the Request::Arguments
        def operation
          Request::Arguments.operation
        end

        protected

          # Fields come from the type klass of the current assigned type
          def fields_source
            type_klass.fields
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              @type_klass = find_type!(data[:type])
              parse_directives(:fragment_definition)

              check_assignment!
              parse_selection
            end
          end

        private

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise ExecutionError, <<~MSG.squish unless type_klass.output_type?
              Unable to assing #{type_klass.gql_name} to "#{gql_name}" fragment because
              it is not a output type.
            MSG

            raise ExecutionError, <<~MSG.squish if type_klass.leaf_type?
              Unable to assing #{type_klass.gql_name} to "#{gql_name}" fragment because
              a "#{type_klass.kind}" type can not be the source of a fragmnet.
            MSG
          end

      end
    end
  end
end
