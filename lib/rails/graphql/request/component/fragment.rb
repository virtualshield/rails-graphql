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

        attr_reader :name, :type_klass, :request, :current_object

        def initialize(request, node)
          @name = node[0]
          @request = request

          super(node)

          check_duplicated_fragment!
        end

        # Check if all the sub fields are broadcastable
        def broadcastable?
          selection.each_value.all?(&:broadcastable?)
        end

        # Check if the fragment has been prepared already
        def prepared?
          defined?(@prepared) && @prepared
        end

        # Return a lazy loaded variable proc
        def variables
          Request::Arguments.lazy
        end

        # Access the operation through the Request::Arguments
        def operation
          Request::Arguments.operation
        end

        # Stores all the used variables
        def used_variables
          return @used_variables if defined?(@used_variables)
        end

        # Stores all the used nested fragments
        def used_fragments
          return @used_fragments if defined?(@used_fragments)
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

        # Build the cache object
        def cache_dump
          super.merge(type_klass: all_to_gid(type_klass))
        end

        # Organize from cache data
        def cache_load(data)
          @name = data[:node][0]
          @type_klass = all_from_gid(data[:type_klass])

          super
        end

        protected

          # Fragments always resolve selection unstacked on response, meaning
          # that its fields will be set in the same level as the parent
          def stacked_selection?
            false
          end

          # Wrap the field organization with the collection of variables
          def organize
            organize_then { collect_usages { organize_fields } }
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

            type = type_klass
            object = @current_object
            resolve_then if (object.nil? && type&.operational?) || type =~ object
          end

          # This will just trigger the selection resolver
          def resolve_then(&block)
            super(block) { resolve_fields(@current_object) }
          end

        private

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise ExecutionError, (+<<~MSG).squish unless type_klass.output_type?
              Unable to assign #{type_klass.gql_name} to "#{name}" fragment because
              it is not a output type.
            MSG

            raise ExecutionError, (+<<~MSG).squish if type_klass.leaf_type?
              Unable to assign #{type_klass.gql_name} to "#{name}" fragment because
              a "#{type_klass.kind}" type can not be the source of a fragment.
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

          # Use the information on the operation to collect all the variables
          # and nested fragments that were used inside a fragment
          def collect_usages
            vars_total = operation.used_variables.size
            frag_total = operation.used_fragments.size
            yield
          ensure
            if operation.used_variables.size > vars_total
              @used_variables = Set.new(operation.used_variables.to_enum.drop(vars_total))
            end

            if operation.used_fragments.size > frag_total
              @used_fragments = Set.new(operation.used_fragments.to_enum.drop(frag_total))
            end
          end
      end
    end
  end
end
