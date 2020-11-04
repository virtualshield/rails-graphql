# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component Field
      #
      # This class holds information about a given field that should be
      # collected from the source of where it was requested.
      class Component::Field < Component
        include ValueWriters
        include SelectionSet
        include Directives

        delegate :decorate, to: :type_klass
        delegate :operation, :variables, to: :parent
        delegate :method_name, :resolver, :performer, :type_klass, :leaf_type?,
          :dynamic_resolver?, to: :field

        parent_memoize :request

        attr_reader :name, :alias_name, :parent, :field, :arguments, :current_object

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
          @all_events ||= Helpers.merge_hash_array(field.all_events, super)
        end

        # Get and cache all the arguments for the field
        def all_arguments
          request.cache(:arguments)[field] ||= begin
            if (result = field.all_arguments).any?
              result.each_value.map(&:gql_name).zip(result.each_value).to_h
            else
              {}
            end
          end
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

        # A little extension of the +is_a?+ method that allows checking it using
        # the underlying +field+
        def of_type?(klass)
          super || field.of_type?(klass)
        end

        # When the field is invalid, there's no much to do
        # TODO: Maybe add a invalid event trigger here
        def resolve_invalid(error = nil)
          request.exception_to_error(error, @node) if error.present?

          validate_output!(nil)
          response.safe_add(gql_name, nil)
        rescue InvalidValueError
          raise unless entry_point?
        end

        # When the +type_klass+ of an object is an interface or a union, the
        # field needs to be redirected to the one from the actual resolved
        # +object+ type
        def resolve_with!(object)
          return resolve! if invalid?

          old_field, @field = @field, object[@field.name]
          @current_object = object
          resolve!
        ensure
          @field, @current_object = old_field, nil
        end

        protected

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              check_assignment!

              parse_arguments
              parse_directives
              parse_selection
            end
          end

          # Perform the prepare step
          def prepare_then(&block)
            super { strategy.prepare(self, &block) }
          end

          # Perform the resolve step
          def resolve_then(&block)
            stacked do
              strategy.perform(self) if field.mutation?
              send(field.array? ? 'resolve_many' : 'resolve_one', &block)
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

          # This override allows reasigned fields to perform events. This
          # happens when fields are originally organized from interfaces. If
          # the event is stopped for the object, then it doesn't proceed to the
          # strategy implementation, ensuring compatibility
          def trigger_event(event_name, **xargs)
            return super if !defined?(@current_object) || @current_object.nil?

            listeners = request.cache(:dynamic_listeners)[field] ||= field.all_listeners
            return super unless listeners.include?(event_name)

            callbacks = request.cache(:dynamic_events)[field] ||= field.all_events
            old_events, @all_events = @all_events, callbacks
            super
          ensure
            @all_events = old_events
          end

          # Check if the field was assigned correctly to an output field
          def check_assignment!
            raise MissingFieldError, <<~MSG.squish if field.nil?
              Unable to find a field named "#{gql_name}" on
              #{entry_point? ? operation.kind : parent.type_klass.name}.
            MSG

            raise FieldError, <<~MSG.squish unless field.output_type?
              The "#{gql_name}" was assigned to a non-output type of field: #{field.inspect}.
            MSG

            empty_selection = data[:selection].nil? || data[:selection].null?
            raise FieldError, <<~MSG.squish if field.leaf_type? && !empty_selection
              The "#{gql_name}" was assigned to the #{type_klass.gql_name} which
              is a leaf type and does not have nested fields.
            MSG

            raise FieldError, <<~MSG.squish if !field.leaf_type? && empty_selection
              The "#{gql_name}" was assigned to the #{type_klass.gql_name} which
              is not a leaf type and requires a selection of fields.
            MSG

            raise DisabledFieldError, <<~MSG.squish if field.disabled?
              The "#{gql_name}" was found but it is marked as disabled.
            MSG
          end
      end
    end
  end
end
