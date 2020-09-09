# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQl Sequenced Strategy
      #
      # This is the default resolution strategy, where each operation is
      # performed in sequece, and they don't relate to each other in any way.
      class Strategy::SequencedStrategy < Strategy
        def self.can_resolve?(_) # :nodoc:
          true
        end

        # Executes the strategy in the normal mode
        def resolve!
          response.with_stack(:data) do
            operations.each_value do |op|
              collect_listeners { op.organize! }
              collect_data      { op.prepare! }
              collect_response  { op.resolve! }
            end
          end
        end
      end
    end
  end
end
