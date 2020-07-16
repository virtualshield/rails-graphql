# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component Field
      #
      # This class holds information about a given field that should be
      # collected from the source of where it was requested.
      class Component::Field < Component
        include SelectionSet
        include Directives

        DATA_PARTS = %i[arguments]

        delegate :type_klass, to: :field
        delegate :operation, :variables, :request, to: :parent

        attr_reader :name, :alias_name, :parent, :field, :arguments

        alias args arguments

        def initialize(parent, node, data)
          super(node, data)

          @parent = parent

          @name = data[:name]
          @alias_name = data[:alias]
        end

        # Assign a given +field+ to this class. The field must be an output
        # field, which means that +output_type?+ must be true. It also must be
        # called exactly once per field.
        def assing_to(field)
          raise ArgumentError, <<~MSG.squish if defined?(@assigned)
            The "#{gql_name}" field is already assigned to #{@field.inspect}
          MSG

          @field = field
        end

        # Return the name of the field to be used on the response
        def gql_name
          alias_name || name
        end

        # Fields come from the type klass of the current assigned field
        def fields_source
          type_klass.fields
        end

        protected

          # Organize the field in debug mode
          def debug_organize
            display_name = name
            display_name += " as #{alias_name}" if alias_name.present?

            organize_then do
              logger.indented("#{display_name}: Organized!") do
                logger.puts("* Assigned: #{field.inspect}")

                debug_arguments
                debug_directives
                debug_organize_fields
              end
            end

            logger << "#{display_name}: Error! (#{errors.last[:message]})" if invalid?
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              parse_arguments
              parse_directives
              parse_selection

              check_assignment!
            end
          end

        private

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise MissingFieldError, <<~MSG.squish if field.nil?
              Unable to find a field named "#{gql_name}"
            MSG

            raise FieldError, <<~MSG.squish unless field.output_type?
              The "#{gql_name}" was assigned to a non-output type of field: #{field.inspect}
            MSG

            raise FieldError, <<~MSG.squish if field.leaf_type? && selection.any?
              The "#{gql_name}" was assigned to the #{type_klass.gql_name} which
              is a leaf type and does not have nested fields
            MSG

            raise DisabledFieldError, <<~MSG.squish if field.disabled?
              The "#{gql_name}" was found but it is marked as disabled
            MSG
          end
      end
    end
  end
end
