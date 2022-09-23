# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Component Fragment
      #
      # This class holds information about a given fragment defined using the
      # +fragment+ statement during an execution. This will guide the validation
      # and execution of it.
      class Component::Fragment < Component
        include SelectionSet
        include Directives

        attr_reader :name, :type_klass, :request

        def initialize(request, node)
          @name = node[0]
          @request = request

          super(node)

          check_duplicated_fragment!
        end

        # Return a lazy loaded variable proc
        # TODO: Mark all the dependent variables
        def variables
          Request::Arguments.lazy
        end

        # Access the operation through the Request::Arguments
        # TODO: Operations will always be stack[1]
        def operation
          Request::Arguments.operation
        end

        # Spread should always be performed with a current object, thus the
        # typename comes from it
        def typename
          @current_object.gql_name
        end

        # Only resolve if the +type_klass+ is equivalent to the given +object+
        def resolve_with!(object)
          return if unresolvable?

          @current_object = object
          resolve!
        ensure
          @current_object = nil
        end

        protected

          # Fragments always resolve selection unstacked on response, meaning
          # that its fields will be set in the same level as the parent
          def stacked_selection?
            false
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              @type_klass = find_type!(@node[1])
              parse_directives(@node[2], :fragment_definition)

              check_assignment!
              parse_selection(@node[3])
            end
          end

          # Resolve the spread operation
          def resolve
            return if unresolvable?

            object = @current_object || type_klass
            resolve_then if type_klass =~ object
          end

          # This will just trigger the selection resolver
          def resolve_then(&block)
            super(block) { resolve_fields(@current_object) }
          end

        private

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise ExecutionError, (+<<~MSG).squish unless type_klass.output_type?
              Unable to assing #{type_klass.gql_name} to "#{name}" fragment because
              it is not a output type.
            MSG

            raise ExecutionError, (+<<~MSG).squish if type_klass.leaf_type?
              Unable to assing #{type_klass.gql_name} to "#{name}" fragment because
              a "#{type_klass.kind}" type can not be the source of a fragmnet.
            MSG
          end

          # If there is another fragment with the same name already defined,
          # raise an error
          def check_duplicated_fragment!
            other = request.document[1].find do |other|
              other != @node && name == other[0]
            end

            return if other.nil?
            invalidate!

            request.report_node_error((+<<~MSG).squish, self)
              Duplicated fragment named "#{name}" defined on
              line #{other.begin_line}:#{other.begin_column}
            MSG
          end
      end
    end
  end
end
