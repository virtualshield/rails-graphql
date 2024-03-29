# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper methods for the organize step of a request
      module Organizable
        # Organize the object if it is not already organized
        def organize!
          organize unless defined?(@organized)
        rescue => error
          invalidate!
          report_exception(error)
        ensure
          @organized = true
        end

        # Build the cache object
        def cache_dump
          arguments =
            if @arguments === EMPTY_HASH
              nil
            elsif is_a?(Component::Operation)
              all_to_gid(@arguments.transform_values)
            else
              @arguments.to_h
            end

          { arguments: arguments }
        end

        # Organize from cache data
        def cache_load(data)
          if (args = data[:arguments]).blank?
              @arguments = EMPTY_HASH
          elsif is_a?(Component::Operation)
            @arguments = all_from_gid(args.transform_values)

            unless defined?(@variables)
              @variables = collect_arguments(self, request.args, var_access: false).freeze
            end
          else
            @arguments = request.build(Request::Arguments, args).freeze
          end

          # Always trigger the organized event
          unless unresolvable?
            strategy.add_listeners_from(self)
            trigger_event(:organized)
          end

          # Mark component as organized
          @organized = true
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
              strategy.add_listeners_from(self)
              after_block.call if after_block.present?
              trigger_event(:organized)
            end
          end

          # Helper parser for request arguments (operation variables) that
          # collect necessary arguments from the request
          # Default values forces this method to run even without nodes
          def parse_variables(nodes)
            if nodes.blank?
              @variables = EMPTY_HASH
              @arguments = EMPTY_HASH
              return
            end

            @arguments = {}

            nodes&.each do |node|
              arg_name, type, value, _directives = node
              raise ExecutionError, (+<<~MSG).squish if arguments.key?(arg_name)
                The "#{arg_name}" argument is already defined for this #{kind}.
              MSG

              # TODO: Move this to a better builder of the type
              type_name, dimensions, nullability = type
              xargs = { owner: schema, default: value, array: dimensions > 0 }
              xargs[:nullable] = (nullability & 0b10) == 0
              xargs[:null] = (nullability & 0b01) == 0

              # TODO: Follow up with the support for directives
              item = arguments[arg_name.to_s] = Argument.new(arg_name, type_name, **xargs)
              item.node = node
              item.validate!
            end

            args = collect_arguments(self, request.args, var_access: false)

            @variables = args.freeze
            @arguments.freeze
          rescue ArgumentsError => error
            raise ArgumentsError, (+<<~MSG).squish
              Invalid arguments for #{log_source}: #{error.message}.
            MSG
          end

          # Helper parser for arguments that also collect necessary variables
          # Default values forces this method to run even without nodes
          def parse_arguments(nodes)
            return @arguments = EMPTY_HASH if nodes.blank?

            args = nodes.each.with_object({}) do |(name, value, var_name), hash|
              hash[name.to_s] = var_name.nil? ? value : var_name
            end

            args = collect_arguments(self, args)
            @arguments = request.build(Request::Arguments, args).freeze
          rescue ArgumentsError => error
            raise ArgumentsError, (+<<~MSG).squish
              Invalid arguments for #{gql_name} #{kind}: #{error.message}.
            MSG
          end

          # Build a hash that collect validated values for a set of arguments.
          # The +source+ can either be the list of arguments or an object that
          # responds to +all_arguments+. The +block+ is called when something
          # goes wrong to collect a formatted message.
          def collect_arguments(source, values, var_access: true, &block)
            op_vars = nil

            errors = []
            source = source.all_arguments if source.respond_to?(:all_arguments)
            return unless source.present?

            result = source.each_pair.each_with_object({}) do |(key, argument), hash|
              value = values && values[key]

              # A token means the name of a variable
              if value.is_a?(::GQLParser::Token) && value.of_type?(:variable)
                var_name = value.to_s
                raise ArgumentError, (+<<~MSG).squish unless var_access
                  Unable to use variable "$#{var_name}" in the current scope
                MSG

                op_var = (op_vars ||= operation.all_arguments).try(:[], var_name)
                raise ArgumentError, (+<<~MSG).squish unless op_var.present?
                  The #{operation.log_source} does not define the $#{var_name} variable
                MSG

                # When arguments are not equivalent, they can ended up with
                # invalid values, so this already ensures that whatever the
                # variable value ended up being, it will be valid due to this
                raise ArgumentError, (+<<~MSG).squish unless op_var =~ argument
                  The $#{var_name} variable on #{operation.log_source} is not compatible
                  with "#{key}" argument
                MSG

                # Mark the variable as used and grab the value
                operation.used_variables << var_name
                value = variables[op_var.name]
              elsif !value.nil?
                # Only when the given value is an actual value that we check if
                # it is valid
                raise ArgumentError, (+<<~MSG).squish unless argument.valid?(value)
                  Invalid value "#{value.to_s}" provided to
                  #{argument.node ? "$#{argument.name} variable" : "#{key} argument"}
                  on #{argument.node ? operation.log_source : gql_name}
                MSG

                value = argument.deserialize(value)
              elsif argument.default_value?
                # Ensure to always import arguments that have default values but
                # were not included in the field
                value = argument.deserialize
              else
                # Otherwise, simply just skip the argument
                next
              end

              hash[argument.name] = value
            rescue ArgumentError => error
              errors << error.message
            end

            # Checks for any required argument that was not provided
            source.each_value do |argument|
              next if result.key?(argument.name) || argument.null?
              errors << +"the \"#{argument.gql_name}\" argument can not be null"
            end

            return result if errors.blank?
            raise ArgumentsError, errors.to_sentence
          end
      end
    end
  end
end
