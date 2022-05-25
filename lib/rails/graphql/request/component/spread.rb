# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Component Spread
      #
      # This class holds information about a given spread that should be
      # iterated, which connect to either a fragment or an inline selection
      class Component::Spread < Component
        include SelectionSet
        include Directives

        delegate :operation, :typename, to: :parent
        delegate :variables, to: :operation

        parent_memoize :request

        attr_reader :name, :parent, :fragment, :type_klass

        def initialize(parent, node)
          @parent = parent

          @name = node[0]
          @inline = name.nil?

          super(node)
        end

        # Check if the object is an inline spread
        def inline?
          @inline.present?
        end

        # Redirect to the fragment or check the inline type before resolving
        def resolve_with!(object)
          return if unresolvable?

          @current_object = object
          resolve!
        ensure
          @current_object = nil
        end

        protected

          # Spread always resolve inline selection unstacked on response,
          # meaning that its fields will be set in the same level as the parent
          def stacked_selection?
            false
          end

          # Just provide the correct location for directives
          def parse_directives(nodes)
            super(nodes, (inline? ? :inline_fragment : :fragment_spread))
          end

          # Scope the arguments whenever stacked within a spread
          def stacked(*)
            Arguments.scoped(operation) { super }
          end

          # Normal mode of the organize step
          # TODO: Once the fragment is organized, double checks the needed
          # variables to ensure that the operation has everything necessary
          def organize
            inline? ? organize_then { organize_fields } : organize_then do
              run_on_fragment(:organize!)
              # Ensure necessary variables
            end
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              if inline?
                @type_klass = find_type!(@node[1])
                parse_directives(@node[2])
                parse_selection(@node[3])
              else
                parse_directives(@node[2])
                @fragment = collect_fragment
                raise ArgumentError, (+<<~MSG).squish if @fragment.nil?
                  The "#{name}" fragment is not defined in this request.
                MSG
              end
            end
          end

          # Spread has a special behavior when using a fragment
          def prepare
            return super if inline?
            raise(+'Prepare with fragment not implemented yet')
          end

          # Resolve the spread operation
          def resolve
            return if unresolvable?

            object = (defined?(@current_object) && @current_object) || parent.type_klass
            return run_on_fragment(:resolve_with!, object) unless inline?

            super if type_klass =~ object
          end

          # This will just trigger the selection resolver
          def resolve_then(&block)
            super(block) { resolve_fields(@current_object) }
          end

          # Most of the things that are redirected to the fragment needs to run
          # inside a arguments scoped
          def run_on_fragment(method_name, *args)
            Arguments.scoped(operation) { fragment.public_send(method_name, *args) }
          end

          # Make sure to instantiate the fragment only when the spread request it
          def collect_fragment
            node = request.fragments[name]
            return node if node.is_a?(Component::Fragment)
            request.fragments[name] = request.build(Component::Fragment, request, node)
          end
      end
    end
  end
end
