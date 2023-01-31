# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Component Field
      #
      # This class holds information about a given field that should be
      # collected from the source of where it was requested.
      class Component::Field < Component
        include Authorizable
        include ValueWriters
        include SelectionSet
        include Directives

        delegate :decorate, to: :type_klass
        delegate :operation, :variables, :request, to: :parent
        delegate :method_name, :resolver, :performer, :type_klass,:leaf_type?,
          :dynamic_resolver?, :mutation?, to: :field

        attr_reader :name, :alias_name, :parent, :field, :arguments, :current_object

        alias args arguments

        def initialize(parent, node)
          @parent = parent

          @name = node[0]
          @alias_name = node[1]

          super(node)
        end

        # Override that considers the requested field directives and also the
        # definition field events, both from itself and its directives events
        def all_listeners
          request.nested_cache(:listeners, field) do
            if !field.listeners?
              directive_listeners
            elsif !directives?
              field.all_listeners
            else
              local = directive_listeners
              local.empty? ? field.all_listeners : field.all_listeners + local
            end
          end
        end

        # Override that considers the requested field directives and also the
        # definition field events, both from itself and its directives events
        def all_events
          request.nested_cache(:events, field) do
            if !field.events?
              directive_events
            elsif !directives?
              field.all_events
            else
              Helpers.merge_hash_array(field.all_events, directive_events)
            end
          end
        end

        # Get and cache all the arguments for the field
        def all_arguments
          return unless field.arguments?

          request.nested_cache(:arguments, field) do
            field.all_arguments.each_value.with_object({}) do |argument, hash|
              hash[argument.gql_name] = argument
            end
          end
        end

        # Check if the field is using a directive
        def using?(item_or_symbol)
          super || field.using?(item_or_symbol)
        end

        # Assign a given +field+ to this class. The field must be an output
        # field, which means that +output_type?+ must be true. It also must be
        # called exactly once per field.
        def assign_to(field)
          raise ArgumentError, (+<<~MSG).squish if defined?(@assigned)
            The "#{gql_name}" field is already assigned to #{@field.inspect}.
          MSG

          @field = field
        end

        # Return the name of the field to be used on the response
        def gql_name
          alias_name || name
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

        # Fields are assignable because they are actually the selection, so they
        # need to be assigned to a filed
        def assignable?
          true
        end

        # Check if all the sub fields are broadcastable
        # TODO: Maybe check for interfaces and if all types allow broadcast
        def broadcastable?
          value = field.broadcastable?
          value = schema.config.default_subscription_broadcastable if value.nil?
          value != false
        end

        # A little extension of the +is_a?+ method that allows checking it using
        # the underlying +field+
        def of_type?(klass)
          super || field.of_type?(klass)
        end

        # When the field is invalid, there's no much to do
        # TODO: Maybe add a invalid event trigger here
        def resolve_invalid(error = nil)
          request.exception_to_error(error, self) if error.present?

          validate_output!(nil)
          response.safe_add(gql_name, nil)
        rescue InvalidValueError
          raise unless entry_point?
        end

        # When the +type_klass+ of an object is an interface or a union, the
        # field needs to be redirected to the one from the actual resolved
        # +object+ type
        def resolve_with!(object)
          return if skipped?
          return resolve! if invalid?

          old_field, @field = @field, object[@field.name]
          request.nested_cache(:listeners, field) { strategy.add_listeners_from(self) }
          @current_object = object
          resolve!
        ensure
          @field, @current_object = old_field, nil
        end

        # Build the cache object
        # TODO: Add the arguments into the GID, but the problem is variables
        def cache_dump
          super.merge(field: (field && all_to_gid(field)))
        end

        # Organize from cache data
        def cache_load(data)
          @name = data[:node][0]
          @alias_name = data[:node][1]
          @field = all_from_gid(data[:field])
          super

          check_authorization! unless unresolvable?
        end

        protected

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              check_assignment!

              parse_directives(@node[3])
              check_authorization!

              parse_arguments(@node[2])
              parse_selection(@node[4])
            end
          end

          # Perform the prepare step
          def prepare_then(&block)
            super { strategy.prepare(self, &block) }
          end

          # Perform the resolve step
          def resolve_then(&block)
            stacked do
              send((field.array? ? :resolve_many : :resolve_one), &block)
            rescue StandardError => error
              resolve_invalid(error)
            end
          end

          # Don't stack over response when it's processing as array
          def stacked_selection?
            !field.array?
          end

        private

          # Resolve the value of the field for a single information
          def resolve_one
            strategy.resolve(self, decorate: true) do |value|
              yield value if block_given?
              trigger_event(:finalize)
            end
          end

          # Resolve the field for a list of information
          def resolve_many
            strategy.resolve(self, array: true) do |item|
              strategy.resolve(self, item, decorate: true) do |value|
                yield value if block_given?
                trigger_event(:finalize)
              end
            end
          end

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise MissingFieldError, (+<<~MSG).squish if field.nil?
              Unable to find a field named "#{gql_name}" on
              #{entry_point? ? operation.kind : parent.type_klass.name}.
            MSG

            raise FieldError, (+<<~MSG).squish unless field.output_type?
              The "#{gql_name}" was assigned to a non-output type of field: #{field.inspect}.
            MSG

            if @node[4].nil?
              raise FieldError, (+<<~MSG).squish if !field.leaf_type?
                The "#{gql_name}" was assigned to the #{type_klass.gql_name} which
                is not a leaf type and requires a selection of fields.
              MSG
            else
              raise FieldError, (+<<~MSG).squish if field.leaf_type?
                The "#{gql_name}" was assigned to the #{type_klass.gql_name} which
                is a leaf type and does not have nested fields.
              MSG
            end

            raise DisabledFieldError, (+<<~MSG).squish if field.disabled?
              The "#{gql_name}" was found but it is marked as disabled.
            MSG
          end
      end
    end
  end
end
