# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Fragment
      #
      # This class holds information about a given fragment defined using the
      # +fragment+ statement during an execution. This will guide the validation
      # and execution of it.
      class Fragment
        include SelectionSet
        include Directives

        DATA_PARTS = %i[type]

        delegate :schema, to: :@request
        delegate :kind, to: :class

        attr_reader :name, :type, :node, :data, :request

        alias gql_name name

        def self.kind
          :fragment
        end

        def initialize(request, node, data)
          super if defined? super

          @request = request
          @node = node
          @name = data[:name]
          @data = data.slice(*data_parts)
        end

        # List of necessary parts from data used for preparation step
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        # Check if the fragment was already prepared
        def prepared?
          data.nil?
        end

        # Prepare the fragment if is not already prepared
        def prepare!
          prepare unless prepared?
        end

        # Check if the fragment is in an invalid state
        def invalid?
          @invalid.present?
        end

        private

          def prepare
            request.stacked(self) do
              @type = schema.find_type!(data[:type])

              parse_directives!(:fragment_definition)
              parse_selection!

              request.trigger_event(:prepare)
            rescue StandardError => e
              request.exception_to_error(e, node, stage: :prepare)
              @invalid = true
            end

            @data = nil
          end
      end
    end
  end
end
