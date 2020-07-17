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

        delegate :type_klass, :all_directives, to: :field
        delegate :operation, :variables, to: :parent

        parent_memoize :request

        attr_reader :name, :alias_name, :parent, :field, :arguments, :tmp_klass, :op_vars

        alias args arguments

        def initialize(parent, node, data)
          @parent = parent

          @name = data[:name]
          @alias_name = data[:alias]

          super(node, data)
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

        # A little helper for finding the parent type name
        def typename
          (try(:tmp_klass) || try(:type_klass))&.gql_name
        end

        # Temporarily redirect the real field of this request field for one
        # with the same name from the given +object+, already assuming that the
        # schema is correctly defined and this shifting is possible
        def resolve_with!(object)
          unless invalid?
            @tmp_klass = object
            old_field, @field = @field, object[@field.name]
          end

          if strategy.debug_mode?
            logger.puts("# As #{@tmp_klass.gql_name}") \
              if @tmp_klass && @tmp_klass != type_klass

            debug_resolve!
          else
            resolve!
          end
        ensure
          @field = old_field
          @tmp_klass = nil
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
          rescue StandardError => error
            logger << "#{display_name}: Error! (#{error.message})"
            raise
          end

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

          # Just trigger the resolve then part of the process
          def resolve(perform = false)
            resolve_then { trigger_event(:finalize) }
          end

          # Just write the field as nil if possible
          def resolve_as_nil
            field&.validate_output!(nil)
            response.safe_add(gql_name, nil)
            logger << "#{gql_name}: nil" if field.leaf_type? && strategy.debug_mode?
          rescue InvalidOutputError
            raise unless parent === operation
          end

          alias resolve_invalid resolve_as_nil

          # Resolve the field in debug mode
          def debug_resolve(perform = false)
            if perform
              resolve_then do |value|
                trigger_event(:finalize)
                logger << "#{gql_name}: #{value}" if field.leaf_type?
              end
            else
              field.leaf_type? ? debug_resolve(true) : logger.indented("#{gql_name}: ") do
                debug_resolve(true)
              end
            end
          end

          # Perform the resolve step
          def resolve_then(first = true, &block)
            return response.with_stack(gql_name, array: field.array?) do
              resolve_then(false, &block)
            end if first && !field.leaf_type?

            stacked do
              method_name = "resolve_#{field.array? ? 'many' : 'one'}"
              field.validate_output!(send(method_name, &block))
            end
          rescue StandardError => error
            resolve_as_nil
          end

          # Write a value based on a Union type
          def write_union(value)
            object = type_klass.all_members.reverse_each.find { |t| t.valid_member?(value) }
            object.nil? ? raise_invalid_member! : write_object(value)
          end

          # Write a value based on a Interface type
          def write_interface(value)
            object = type_klass.all_types.reverse_each.find { |t| t.valid_member?(value) }
            object.nil? ? raise_invalid_member! : write_object(value)
          end

          # Write a value based on a Object type
          def write_object(value, object = nil)
            object ||= type_klass.valid_member?(value) ? type_klass : raise_invalid_member!

            selection.each_value.with_index do |field, i|
              logger&.eol if i > 0
              field.resolve_with!(object)
            end
          end

          # Write a value with the correct serialize mode
          def write_scalar(value)
            serializer = response.try(:prefer_string?) ? :to_json : :to_hash
            response.add(gql_name, type_klass.public_send(serializer, value))
          end

        private

          # Resolve the value of the field for a single information
          def resolve_one(item = nil, &block)
            strategy.data_for(field, item) do |item|
              return resolve_as_nil if item.nil?

              writer = 'write_' + field.kind.to_s
              writer = 'write_scalar' unless respond_to?(writer, true)

              block.call(item)
              send(writer, item)
            end
          end

          # Resolve the field for a list of information
          def resolve_many(&block)
            strategy.data_for(field) do |items|
              return resolve_as_nil unless items.respond_to?(:map)

              items.map.with_index do |value, idx|
                stacked(idx) do
                  resolve_one(value, &block)
                  response.next
                rescue StandardError => e
                  real_error = ActiveSupport::Inflector.ordinalize(idx)
                  real_error += " result of the #{gql_name} field"
                  source_error = "The #{gql_name} field result"

                  e.message.gsub!(source_error, real_error)
                  raise
                end
              end
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

          # A problem when an object-based value is not a valid member of the
          # +type_klass+ of this field
          def raise_invalid_member!
            raise(FieldError, <<~MSG.squish)
              The #{gql_name} field result is not a member of #{type_klass.gql_name}.
            MSG
          end
      end
    end
  end
end
