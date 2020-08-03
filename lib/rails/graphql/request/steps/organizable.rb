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

        protected

          # Normally, fields come from the +type_klass+
          def fields_source
            type_klass.fields
          end

          # Normal mode of the organize step
          def organize
            organize_then { organize_fields }
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
              # TODO: Share this behavior of argument/variable assignment
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
              variables[arg.name] = arg.deserialize(value) unless value.nil?
            end unless data[:variables].empty?

            @var_args.freeze
            @variables.freeze
          end

          # Helper parser for arguments that also collect necessary variables
          def parse_arguments
            @arguments = request.build(Request::Arguments)
            @op_vars = {}

            parser = all_arguments
            visitor.collect_arguments(*data[:arguments]) do |data|
              # TODO: Share this behavior of argument/variable assignment
              arg_name = data[:name]
              variable = data[:variable]

              raise ArgumentError, <<~MSG.squish unless parser.key?(arg_name)
                The "#{gql_name}" field does not contain a "#{arg_name}" argument.
              MSG

              # There's no need for further checkings if the value comes from a
              # operation variable
              if variable.present?
                op_vars[arg_name] = variable
                arguments[arg_name.underscore] = variables[variable]
                next
              end

              # Deserialize the value and check if it is a valid input
              field_argument = parser[arg_name]
              value = field_argument.deserialize(data[:value])
              raise ArgumentError, <<~MSG.squish unless field_argument.valid?(value)
                The value provided for the "#{arg_name}" on "#{gql_name}" field is invalid.
              MSG

              arguments[arg_name.underscore] = value
            end unless data[:arguments].empty?

            @op_vars.freeze
            @arguments.freeze
          end
      end
    end
  end
end
