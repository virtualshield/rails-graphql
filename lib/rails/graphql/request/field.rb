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

        delegate :variables, :request, to: :@operation
        delegate :schema, :visitor, :response, to: :request
        delegate :kind, to: :class

        attr_reader :name, :alias_name, :node, :parent, :data, :field, :arguments

        alias args arguments

        def self.kind
          :field
        end

        def initialize(parent, node, data)
          @node = node
          @parent = parent
          @operation = parent.try(:parent) || parent

          @name = data[:name]
          @alias_name = data[:alias]
          @data = data.slice(*data_parts)
        end

        # List of necessary parts from data used for preparation step
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        # Return the name of the field to be used on the response
        def gql_name
          alias_name || name
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

          request.stacked(self) do
            do_prepare!

            response.indented("Field #{gql_name}: Prepared!") do
              response.indented("* Arguments(#{arguments.each_pair.size})") do
                arguments.each_pair { |(k, v)| response << "#{k}: #{v.inspect}" }
              end if arguments.each_pair.any?

              debug_directives!
              debug_fields!
            end
          rescue StandardError => e
            response << "Field #{gql_name}: Error! (#{e.message})"
          end
        end

        # Check if the field is in an invalid state
        def invalid?
          @invalid.present?
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
      end
    end
  end
end
