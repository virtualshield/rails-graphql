# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Debugger Extension
      #
      # This add tracking behavior to all necessary objects during a request.
      # It relies on the extension behavior under the requests
      module Debugger # :nodoc: all
        module Request
          attr_reader :logger

          def execute(document, *args, stdout: $stdout, **xargs)
            @logger = Collectors::IdentedCollector.new(auto_eol: false)

            logger.puts('# Document')
            logger.puts(document)

            super
          ensure
            stdout.puts(logger.value)
          end

          private

            def find_strategy!
              strategy = nil
              logger.indented('# Selecting strategy:') do
                strategy = strategies.lazy.map do |klass_name|
                  klass_name.constantize
                end.select do |klass|
                  result = klass.can_resolve?(self)
                  logger.puts(<<~LOG.squish)
                    #{klass.name}[#{klass.priority}] is #{result ? 'a' : 'no'} match!
                  LOG

                  result
                end.max_by(&:priority)

                logger.eol
                logger.puts("Selected: #{strategy.name}")
                strategy = build(strategy, self)
              end.eol

              strategy
            end
        end

        module Component
          def debug_directives
            logger.indented("* Directives(#{directives.size})") do
              directives.each { |x| logger << x.inspect }
            end if directives.any?
          end

          def debug_variables
            size = variables.instance_variable_get(:@table).size
            logger.indented("* Variables(#{size})") do
              variables.each_pair.with_index do |(k, v), i|
                logger.eol if i > 0
                logger << "#{k}: #{v.inspect}"
              end
            end if size > 0
          end

          def debug_arguments
            size = arguments.instance_variable_get(:@table).size
            logger.indented("* Arguments(#{size})") do
              arguments.each_pair.with_index do |(k, v), i|
                logger.eol if i > 0
                logger << "#{k}: #{v.inspect}"
              end
            end if size > 0
          end

          def organize_fields
            logger.indented("* Fields(#{selection.size})") do
              selection.each_value.with_index do |field, i|
                logger.eol if i > 0
                field.organize!
              end
            end if selection.any?
          end

          def write_object(*)
            first_item = selection.each_value.first
            first_item.instance_variable_set(:@log_array, true)
            super
          ensure
            first_item.instance_variable_set(:@log_array, false)
          end

          protected

            def name_with_alias
              name + (alias_name.present? ? " as #{alias_name}" : '')
            end
        end

        module Component_Fragment
          def organize
            header_line = "Fragment #{name}"

            organize_then do
              logger.indented("#{header_line} on #{type_klass.gql_name}: Organized!") do
                debug_directives
                organize_fields
              end
            end
          rescue StandardError => error
            logger << "#{header_line}: Error! (#{error.message})"
            raise
          end
        end

        module Component_Spread
          def organize
            header_line = 'Spread'

            organize_then do
              logger.indented('Spread: Organized!') do
                debug_directives

                if inline?
                  logger.puts("* Inline: #{type_klass.inspect}")
                  organize_fields
                else
                  debug_organize_fragment
                end
              end
            end
          rescue StandardError => error
            logger << "Spread: Error! (#{error.message})"
            raise
          end

          private

            def debug_organize_fragment
              unless fragment.organized?
                logger.puts("* Fragment: #{fragment.name}")
                return fragment.organize! 
              end

              return logger.puts("* Fragment: #{fragment.name} [invalidated]") \
                if fragment.invalid?

              logger.puts("* Fragment: #{fragment.name} [Reused]")
              logger.indented("Fragment #{name} on #{fragment.type_klass.gql_name}: Organized!") do
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

                      debug_fragment_fields(item.selection, &self_block) \
                        if item.selection.any?
                    end
                  end
                end if fragment.selection.any?
              end
            end

            def debug_fragment_fields(fields = fragment.selection, &block)
              fields.each_value.with_index do |field, i|
                block.call(field, i, block)
              end
            end
        end

        module Component_Typename
          def organize_then
            super

            logger.indented("#{name_with_alias}: Organized!") do
              logger.puts("* Assigned: Dynamic Typename")
              debug_directives
            end
          rescue StandardError => error
            logger << "#{name_with_alias}: Error! (#{error.message})"
            raise
          end

          def resolve
            resolve_then { |value| logger << "#{gql_name}: #{value}" }
          end
        end

        module Component_Field
          def organize_then
            organize_then do
              logger.indented("#{name_with_alias}: Organized!") do
                logger.puts("* Assigned: #{field.inspect}")

                debug_arguments
                debug_directives
                organize_fields
              end
            end
          rescue StandardError => error
            logger << "#{name_with_alias}: Error! (#{error.message})"
            raise
          end

          def resolve_as_nil
            super
            logger << "#{gql_name}:" if leaf_type?
          end

          def resolve
            logger.puts("# As #{@tmp_klass.gql_name}") \
              if @tmp_klass.present?

            prefix = @log_array ? '- ' : ''
            if !leaf_type?
              logger.indented("#{prefix}#{gql_name}:") { super }
            elsif field.array?
              logger.indented("#{prefix}#{gql_name}:") do
                @log_array = true
                debug_resolve
              ensure
                @log_array = false
              end
            else
              debug_resolve
            end
          end

          def debug_resolve
            resolve_then do |value|
              prefix = @log_array ? '- ' : ''
              logger << "#{prefix}#{gql_name}: #{value}"
            end
          end
        end

        module Component_Operation
          def organize!
            logger.indented('# Organize stage') { super }
          end

          def prepare!
            logger.indented('# Prepare stage') { super }
          end

          def resolve!
            logger.indented('# Resolve stage') { super }
          end

          def organize
            header_line = "Operation #{display_name} as #{kind}"
            organize_then do
              logger.indented("#{header_line}: Organized!") do
                trigger_event(kind)
                yield if block_given?

                debug_variables
                debug_directives
                organize_fields
              end
            end
          rescue StandardError => error
            logger << "#{header_line}: Error! (#{error.message})"
            raise
          end

          def resolve_then
            logger.indented("#{name}:") { super }
          end

          def resolve_invalid
            super
            logger << "#{name}: null" if name.present?
          end
        end
      end
    end
  end
end
