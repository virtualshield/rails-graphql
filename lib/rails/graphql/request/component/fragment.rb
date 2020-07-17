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

          # Organize the fragment in debug mode
          def debug_organize
            display_name = "Fragment #{name}"

            organize_then do
              logger.indented("#{display_name} on #{type_klass.gql_name}: Organized!") do
                logger.puts("* Assigned: #{type_klass.inspect}")

                debug_directives
                debug_organize_fields
              end
            end

            logger << "#{display_name}: Error! (#{errors.last[:message]})" if invalid?
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              @type_klass = find_type!(data[:type])

              parse_directives(:fragment_definition)
              parse_selection
            end
          end
      end
    end
  end
end
