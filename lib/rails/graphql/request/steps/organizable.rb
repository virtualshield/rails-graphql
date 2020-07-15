# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper methods for the organize step of a request
      module Organizable
        # Check if it is already organized
        def organized?
          data.nil?
        end

        # Organize the obnject if is not already organized
        def organize!
          organize unless organized?
        end

        # Organize the object in debug mode
        def debug_organize!
          debug_organize unless organized?
        end

        protected

          # Normal mode of the organize step
          def organize
            organize_then { organize_fields }
          end

          # Debug mode of the organize step
          def debug_organize
            raise NotImplementedError
          end

          # The actula process that organizes the object
          def organize_then(after_block, &block)
            stacked do
              block.call
              trigger_event(:organize)
              after_block.call
            rescue StandardError => error
              request.exception_to_error(error, @node, stage: :organize)
              invalidate!
            ensure
              @data = nil
            end
          end

          # Helper parser for request arguments (operation variables) that
          # collect necessary arguments from the request
          def parse_variables
            @variables = OpenStruct.new

            parser = Request::VariableParser.new(self, request.args)
            visitor.collect_variables(*data[:variables]) do |data|
              parser.resolve(data, variables)
            end unless data[:variables].empty?

            @variables.freeze
          end

          # Display the variables on the debug process
          def debug_variables
            size = variables.instance_variable_get(:@table).size
            logger.indented("* Variables(#{size})") do
              variables.each_pair.with_index do |(k, v), i|
                logger.eol if i > 0
                logger << "#{k}: #{v.inspect}"
              end
            end if size > 0
          end

          # Helper parser for arguments that also collect necessary variables
          def parse_arguments
            @arguments = Request::Arguments.new

            visitor.collect_arguments(*data[:arguments]) do |data|
              variable = data[:variable]
              arguments[data[:name].underscore] = variable.present? \
                ? variables[variable] \
                : data[:value]
            end unless data[:arguments].empty?

            @arguments.freeze
          end

          # Display the arguments on the debug process
          def debug_arguments
            size = arguments.instance_variable_get(:@table).size
            logger.indented("* Arguments(#{size})") do
              arguments.each_pair.with_index do |(k, v), i|
                logger.eol if i > 0
                logger << "#{k}: #{v.inspect}"
              end
            end if size > 0
          end
      end
    end
  end
end
