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

        # Organize the object if it is not already organized
        def organize!
          capture_exception(:organize, true) do
            unless organized?
              organize
              strategy.add_listener(self)
            end
          end
        end

        # Organize the object in debug mode
        def debug_organize!
          capture_exception(:organize, true) do
            unless organized?
              debug_organize
              strategy.add_listener(self)
            end
          end
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

          # The actual process that organizes the object
          def organize_then(after_block, &block)
            stacked do
              block.call
              trigger_event(:organize)
              after_block.call if after_block.present?
            end
          ensure
            @data = nil
          end

          # Helper parser for request arguments (operation variables) that
          # collect necessary arguments from the request
          def parse_variables
            @variables = OpenStruct.new
            @var_args = {}

            visitor.collect_variables(*data[:variables]) do |data|
              arg_name = data[:name]
              raise ExecutionError, <<~MSG.squish if var_args.key?(arg_name)
                The "#{arg_name}" argument is already defined for this #{kind}.
              MSG

              extra = data.except(:name, :type).merge(owner: schema)
              arg = Argument.new(arg_name, data[:type], **extra)
              arg.validate!

              value = request.args[arg.gql_name]
              value = arg.default if value.nil?

              raise ArgumentError, <<~MSG.squish unless arg.valid?(value)
                Invalid value "#{value.inspect}" for "$#{arg.gql_name}" argument.
              MSG

              var_args[arg.gql_name] = arg
              variables[arg.name] = arg.to_hash(value) unless value.nil?
            end unless data[:variables].empty?

            @var_args.freeze
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
            @op_vars = {}

            visitor.collect_arguments(*data[:arguments]) do |data|
              arg_name = data[:name]
              variable = data[:variable]

              op_vars[arg_name]  = variable if variable.present?
              arguments[arg_name.underscore] = variable.present? \
                ? variables[variable] \
                : data[:value]
            end unless data[:arguments].empty?

            @op_vars.freeze
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
