# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Field
      #
      # This class holds information about a given field that should be
      # collected from the source of where it was requested.
      class Field
        include SelectionSet
        include Directives

        DATA_PARTS = %i[arguments]

        delegate :variables, :request, to: :operation
        delegate :memo, :visitor, :response, to: :request
        delegate :type_klass, to: :field
        delegate :operation, to: :@parent
        delegate :kind, to: :class

        attr_reader :name, :alias_name, :node, :parent, :data, :field, :arguments

        alias args arguments

        def self.kind
          :field
        end

        def initialize(parent, node, data)
          @node = node
          @parent = parent

          @name = data[:name]
          @alias_name = data[:alias]
          @data = data.slice(*data_parts)
        end

        # Assign a given +field+ to this class. The field must be an output
        # field, which means that +output_type?+ must be true
        def assing_field(field)
          raise ArgumentError, <<~MSG.squish if assigned?
            The "#{gql_name}" field is already assigned to #{@field.inspect}
          MSG

          @field = field
        end

        # List of necessary parts from data used for preparation step
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        # Return the name of the field to be used on the response
        def gql_name
          alias_name || name
        end

        # Check if the real field was assigned
        def assigned?
          defined?(@assigned)
        end

        # Check if the field is in an invalid state
        def invalid?
          @invalid.present?
        end

        # Check if the field was already prepared
        def prepared?
          data.nil?
        end

        # Prepare the field if is not already prepared
        def prepare!
          prepare unless prepared?
        end

        # Prepare the field in debug mode
        def debug_prepare!
          return if prepared?

          display_name = name
          display_name += " as #{alias_name}" if alias_name.present?

          request.stacked(self) do
            do_prepare!

            response.indented("#{display_name}: Prepared!") do
              response.puts("* Assigned: #{field.inspect}")
              response.indented("* Arguments(#{arguments.each_pair.size})") do
                arguments.each_pair.with_index do |(k, v), i|
                  response.eol if i > 0
                  response << "#{k}: #{v.inspect}"
                end
              end if arguments.each_pair.any?

              debug_directives!
              debug_fields!
            end
          rescue StandardError => e
            response << "Field #{display_name}: Error! (#{e.message})"
          end
        end

        protected

          # Fields come from the type klass of the current assigned field
          def fields_source
            type_klass.fields
          end

        private

          def prepare
            request.stacked(self) do
              do_prepare!
            rescue StandardError => e
              @invalid = true
            end
          end

          def do_prepare!
            check_assignment!

            parse_arguments!
            parse_directives!
            parse_selection!

            request.trigger_event(:prepare)
          rescue StandardError => e
            request.exception_to_error(e, node, stage: :prepare)
            raise
          ensure
            @data = nil
          end

          def parse_arguments!
            @arguments = OpenStruct.new

            visitor.collect_arguments(*data[:arguments]) do |data|
              variable = data[:variable]
              arguments[data[:name].underscore] = variable.present? \
                ? variables[variable] \
                : data[:value]
            end unless data[:arguments].empty?

            @arguments.freeze
          end

          def check_assignment!
            raise FieldError, <<~MSG.squish if field.nil?
              Unable to find a field named "#{gql_name}"
            MSG

            raise FieldError, <<~MSG.squish unless field.output_type?
              The "#{gql_name}" was assigned to a non-output type of field: #{field.inspect}
            MSG
          end
      end
    end
  end
end
