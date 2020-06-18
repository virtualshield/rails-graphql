# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Fragment
      #
      # This class holds information about a given fragment. This will guide the
      # validation and execution of it.
      class Fragment
        delegate :memo, :schema, :visitor, :errors, :args, to: :@request

        attr_reader :name, :type, :node, :data, :directives, :request

        def initialize(request, node, data)
          @request = request
          @node = node
          @name = data[:name]
          @data = data.slice(:type, :directives, :selection)
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

              parse_directives!
              # parse_selection!

              request.trigger_event(:prepare)
            rescue StandardError => e
              request.exception_to_error(e, node, stage: :prepare)
              @invalid = true
            end

            @data = nil
          end

          def parse_directives!
            @directives = []
            event = GraphQL::Event.new(:attach, self, :execution)
            visitor.collect_directives(data[:directives]) do |data|
              item = GraphQL.type_map.fetch!(
                data[:name],
                base_class: :Directive,
                namespaces: schema.namespaces,
              ).new(**data[:arguments])

              event.trigger_for(item)
              directives << item
            end
          end
      end
    end
  end
end
