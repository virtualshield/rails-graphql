# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Component Spread
      #
      # This class holds information about a given spread that should be
      # iterated, which connect to either a fragment or an inline selection
      class Component::Spread < Component
        include SelectionSet
        include Directives

        DATA_PARTS = %i[type]

        delegate :operation, :fields_source, :typename, to: :parent

        parent_memoize :request

        attr_reader :name, :parent, :fragment, :type_klass

        def initialize(parent, node, data)
          @parent = parent

          @name = data[:name]
          @inline = data[:inline]

          super(node, data)
        end

        # Check if the object is an inline spread
        def inline?
          @inline.present?
        end

        # Fields come from the parent scope, since the spread happens inside
        # a field or an operation
        def fields_source
          parent.fields_source
        end

        # Return a lazy loaded variable proc
        def variables
          Request::Arguments.lazy
        end

        protected

          # Scope the arguments whenever stacked within a spread
          def stacked(*)
            Request::Arguments.scoped(operation) { super }
          end

          # Normal mode of the organize step
          def organize
            organize_then { inline? ? organize_fields : fragment.organize! }
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              parse_directives

              if inline?
                @type_klass = find_type!(data[:type])

                parse_selection
              else
                @fragment = request.fragments[name]

                raise ArgumentError, <<~MSG.squish if @fragment.nil?
                  The "#{name}" fragment is not defined in this request.
                MSG
              end
            end
          end
      end
    end
  end
end
