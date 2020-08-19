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
          capture_exception(:organize, true) { organize unless organized? }
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
              strategy.add_listener(self)
              trigger_event(:organize)
              after_block.call if after_block.present?
            end
          ensure
            @data = nil
          end

          # Helper parser for request arguments (operation variables) that
          # collect necessary arguments from the request
          def parse_variables
            @arguments = {}

            visitor.collect_variables(*data[:variables]) do |data, node|
              arg_name = data[:name]
              raise ExecutionError, <<~MSG.squish if arguments.key?(arg_name)
                The "#{arg_name}" argument is already defined for this #{kind}.
              MSG

              extra = data.except(:name, :type).merge(owner: schema)
              item = arguments[arg_name] = Argument.new(arg_name, data[:type], **extra)
              item.node = node
              item.validate!
            end unless data[:variables].empty?

            args = request.sanitized_arguments
            args = collect_arguments(self, args, var_access: false) do |errors|
              "Invalid arguments for #{log_source}: #{errors}."
            end

            @variables = OpenStruct.new(args).freeze
            @arguments.freeze
          end

          # Helper parser for arguments that also collect necessary variables
          def parse_arguments
            args = {}
            visitor.collect_arguments(*data[:arguments]) do |data|
              args[data[:name]] = variable = data[:variable]
              args[data[:name]] = data[:value] if variable.nil? || variable.null?
            end unless data[:arguments].empty?

            args = collect_arguments(self, args) do |errors|
              "Invalid arguments for #{gql_name} #{kind}: #{errors}."
            end

            @arguments = request.build(Request::Arguments, args).freeze
          end

          # Build a hash that collect validated values for a set of arguments.
          # The +source+ can either be the list of arguments or an object that
          # responds to +all_arguments+. The +block+ is called when something
          # goes wrong to collect a formatted message.
          def collect_arguments(source, values, var_access: true, &block)
            op_source = nil
            op_vars = nil

            errors = []
            source = source.all_arguments if source.respond_to?(:all_arguments)
            result = source.each_pair.inject({}) do |result, (key, argument)|
              # Check for argument existance
              raise ArgumentError, <<~MSG.squish unless (value = values[key]).present?
                The "#{key}" argument is not defined.
              MSG

              # Pointer means operation variable
              if value.is_a?(::FFI::Pointer)
                var_name = visitor.node_name(value)
                raise ArgumentError, <<~MSG.squish unless var_access
                  Unable to use variable "$#{var_name}" in the current scope.
                MSG

                op_vars ||= operation.all_arguments
                raise ArgumentError, <<~MSG.squish unless (op_var = op_vars[var_name]).present?
                  The #{operation.log_source} does not define the $#{var_name} variable.
                MSG

                # When arguments are not equivalent, they can ended up with
                # invalid values, so this already ensures that whatever the
                # variable value ended up being, it will be valid due to this
                raise ArgumentError, <<~MSG.squish unless argument =~ op_var
                  The $#{var_name} variable on #{operation.log_source} is not compatible
                  with "#{key}" argument.
                MSG

                operation.used_variables << var_name
                value = variables[var_name]
              else
                # Only when the given value is an actual value that we check if
                # it is valid
                raise ArgumentError, <<~MSG.squish unless argument.valid?(value)
                  Invalid value provided to "#{key}" argument.
                MSG

                value = argument.deserialize(value)
              end

              result[argument.name] = value
              result
            rescue ArgumentError => error
              errors << error.message
              result
            end

            # Checks for any required arugment that was not provided
            source.each_value do |argument|
              next if result.key?(argument.name) || argument.null?
              errors << "The \"#{argument.gql_name}\" argument can not be null."
            end

            return result if errors.blank?
            raise ArgumentError, block.call(errors.to_sentence)
          end
      end
    end
  end
end
