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

        delegate :operation, :variables, to: :parent
        delegate :merge_hash_array!, to: 'Helpers::InheritedCollection'
        delegate :method_name, :resolver, :type_klass, :leaf_type?,
          :dynamic_resolver?, to: :field

        parent_memoize :request

        attr_reader :name, :alias_name, :parent, :field, :arguments,
          :current_object, :op_vars

        alias args arguments

        def initialize(parent, node, data)
          @parent = parent

          @name = data[:name]
          @alias_name = data[:alias]

          super(node, data)
        end

        # Return both the field directives and the request directives
        def all_directives
          field.all_directives + super
        end

        # Override that considers the requested field directives and also the
        # definition field events, both from itself and its directives events
        def all_listeners
          field.all_listeners + super
        end

        # Override that considers the requested field directives and also the
        # definition field events, both from itself and its directives events
        def all_events
          @all_events ||= merge_hash_array!(field.all_events, super)
        end

        # Assign a given +field+ to this class. The field must be an output
        # field, which means that +output_type?+ must be true. It also must be
        # called exactly once per field.
        def assing_to(field)
          raise ArgumentError, <<~MSG.squish if defined?(@assigned)
            The "#{gql_name}" field is already assigned to #{@field.inspect}.
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

        # A little helper for finding the correct parent type name
        def typename
          (try(:current_object) || try(:type_klass))&.gql_name
        end

        # Check if the field is an entry point, meaning that its parent is the
        # operation and it is associated to a schema field
        def entry_point?
          parent.kind === :operation
        end

        # A little extension of the +is_a?+ method that allows checking it using
        # the underlying +field+
        def of_type?(klass)
          super || field.of_type?(klass)
        end

        # When the field is invalid, there's no much to do
        # TODO: Maybe add a invalid event trigger here
        def resolve_invalid
          validate_output!(nil)
          response.safe_add(gql_name, nil)
        rescue InvalidOutputError
          raise unless entry_point?
        end

        protected

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              parse_arguments
              parse_directives

              check_assignment!
              check_arguments!
              parse_selection
            end

            @op_vars = nil
          end

          # Perform the resolve step
          def resolve_then(&block)
            stacked { send("resolve_#{field.array? ? 'many' : 'one'}", &block) }
          rescue StandardError
            resolve_invalid
          end

        private

          # Resolve the value of the field for a single information
          def resolve_one(*args)
            strategy.resolve(self, *args) do |value|
              yield value if block_given?
              trigger_event(:finalize)
            end
          end

          # Resolve the field for a list of information
          def resolve_many(&block)
            strategy.resolve(self, array: true) do |item, idx|
              stacked(idx) { resolve_one(item, &block) }
            rescue StandardError
              resolve_invalid
            end
          end

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise MissingFieldError, <<~MSG.squish if field.nil?
              Unable to find a field named "#{gql_name}" on
              #{parent === operation ? operation.kind : parent.type_klass.name}.
            MSG

            raise FieldError, <<~MSG.squish unless field.output_type?
              The "#{gql_name}" was assigned to a non-output type of field: #{field.inspect}.
            MSG

            raise FieldError, <<~MSG.squish if field.leaf_type? && selection.present?
              The "#{gql_name}" was assigned to the #{type_klass.gql_name} which
              is a leaf type and does not have nested fields.
            MSG

            raise DisabledFieldError, <<~MSG.squish if field.disabled?
              The "#{gql_name}" was found but it is marked as disabled.
            MSG
          end

          # Check if all the arguments are compatible with operation arguments
          # when they are conected via a variable
          def check_arguments!
            field.all_arguments.each_value do |arg|
              op_argument = op_vars[arg.gql_name]
              next if op_argument.nil?

              raise FieldError, <<~MSG.squish unless arg =~ operation.var_args[op_argument]
                The "$#{op_argument}" operation arguemnt is not compatible with
                the "#{arg.gql_name}" argument on the "#{gql_name}" field.
              MSG
            end
          end
      end
    end
  end
end
