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

        delegate :operation, :fields_source, :request, to: :parent

        attr_reader :name, :parent, :fragment, :type_klass

        def initialize(parent, node, data)
          super(node, data)

          @parent = parent

          @name = data[:name]
          @inline = data[:inline]
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

          # Organize the field in debug mode
          def debug_organize
            organize_then do
              logger.indented("Spread: Organized!") do
                debug_directives

                if inline?
                  logger.puts("* Inline: #{type_klass.inspect}")
                  debug_organize_fields
                else
                  debug_organize_fragment
                end
              end
            end

            logger << "Spread: Error! (#{errors.last[:message]})" if invalid?
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

        private

          # Either organize the fragment or mock it's debug state
          def debug_organize_fragment
            logger.puts("* Fragment: #{fragment.name}")
            return fragment.debug_organize! unless fragment.organized?

            logger.puts <<~CONTENT.squish
              Fragment #{fragment.name} on #{fragment.type_klass.gql_name}: [Reused]
            CONTENT

            fragment.send(:debug_directives)
            logger.indented("* Fields(#{fragment.selection.size})") do
              debug_fragment_fields do |item, i, self_block|
                logger.eol if i > 0

                display_name = item.name
                display_name += " as #{item.alias_name}" if item.alias_name.present?

                logger.indented("#{display_name}: Organized!") do
                  logger.puts("* Assigned: #{item.field.inspect}")

                  item.send(:debug_arguments)
                  item.send(:debug_directives)

                  debug_fragment_fields(item.selection, &block) \
                    if item.selection.any?
                end
              end
            end if fragment.selection.any?
          end

          # Fake mode to debug fields regardless their state and allowing
          # recursiveness
          def debug_fragment_fields(fields = fragment.selection, &block)
            fields.each_value.with_index do |field, i|
              block.call(field, i, block)
            end
          end

      end
    end
  end
end
