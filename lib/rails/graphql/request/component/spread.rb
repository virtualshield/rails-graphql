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

        delegate :operation, :typename, to: :parent

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

        # Return a lazy loaded variable proc
        def variables
          Request::Arguments.lazy
        end

        # Redirect to the fragment or check the inline type before resolving
        def resolve_with!(object)
          return if invalid?

          @current_object = object
          resolve!
        ensure
          @current_object = nil
        end

        protected

          # Spread always resolve inline selection unstacked on response,
          # meaning that its fields will be set in the same level as the parent
          def unstacked_selection?
            true
          end

          # Just provide the correct location for directives
          def parse_directives
            super(inline? ? :inline_fragment : :fragment_spread)
          end

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
                # TODO: Add request cache
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

          # Resolve the spread operation
          def resolve
            return if invalid?

            object = @current_object || parent.type_klass
            return fragment.resolve_with!(object) unless inline?

            super if type_klass =~ object
          end

          # This will just trigger the selection resolver
          def resolve_then(&block)
            super(block) { write_selection(@current_object) }
          end
      end
    end
  end
end
