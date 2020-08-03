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

          check_duplicated_fragment!
        end

        # Return a lazy loaded variable proc
        def variables
          Request::Arguments.lazy
        end

        # Access the operation through the Request::Arguments
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
          return if invalid?

          @current_object = object
          resolve!
        ensure
          @current_object = nil
        end

        protected

          # Fragments always resolve selection unstacked on response, meaning
          # that its fields will be set in the same level as the parent
          def unstacked_selection?
            true
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              # TODO: Add request cache
              @type_klass = find_type!(data[:type])
              parse_directives(:fragment_definition)

              check_assignment!
              parse_selection
            end
          end

          # Resolve the spread operation
          def resolve
            return if invalid?

            object = @current_object || type_klass
            resolve_then if type_klass =~ object
          end

          # This will just trigger the selection resolver
          def resolve_then(&block)
            super(block) { write_selection(@current_object) }
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

          # If there is another fragment with the same name already defined,
          # raise an error
          def check_duplicated_fragment!
            return unless request.fragments.key?(name)

            invalidate!

            other_node = request.fragments[name].instance_variable_get(:@node)
            location = GraphQL::Native.get_location(other_node)

            request.report_node_error(<<~MSG.squish, @node)
              Duplicated fragment named "#{name}" found on
              line #{location.begin_line}:#{location.begin_column}
            MSG
          end

      end
    end
  end
end
