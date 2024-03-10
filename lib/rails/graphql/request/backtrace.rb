# frozen_string_literal: true

require 'active_support/parameter_filter'

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Backtrace
      #
      # Display any request errors in a nice way. By default, it won't display
      # anything that is internal of this gem, but
      module Backtrace
        COL_MAX_WIDTH = 100

        mattr_accessor :skip_base_class, instance_accessor: false,
          default: Rails::GraphQL::StandardError

        extend self

        # Check if the given +error+ should be skipped
        # TODO: Maybe check +cause+ to proper evaluate the skip
        def skip?(error)
          error.class <= skip_base_class
        end

        # Display the provided +error+ from the provided +request+
        def print(error, component, request)
          return if skip?(error)

          table = print_table(error, component, request)
          info = print_backtrace(error, request)

          request.schema.logger.error(+"#{table}\n\n#{info}")
        end

        protected

          # Organize and print a table of the place where the error occurred
          def print_table(error, component, request)
            table = begin_table
            stack = [component] + request.stack
            counter = stack.count { |item| !item.is_a?(Numeric) }
            objects = request.strategy.context
            oid = -1

            suffix = nil
            while (item = stack.shift)
              next suffix = +"[#{item}]" if item.is_a?(Numeric)
              location = request.location_of(item)
              location = location[0].values.join(':') if location

              data = [counter, location]
              add = send("row_for_#{item.kind}", data, item, suffix)

              if item.kind == :field
                oid += 1
                data[5] ||= oid == 0 ? '↓' : print_object(objects&.at(oid - 1))
                data[3] ||= print_object(objects&.at(oid))
              end

              data[4] = clean_arguments(data[4], request) if data[4]

              suffix = nil
              counter -= 1
              add_to_table(table, data) if add != false
            end

            stringify_table(table)
          end

          # Print the backtrace steps of the error
          def print_backtrace(error, request)
            steps = error.backtrace
            # steps = cleaner.clean(steps) unless cleaner.nil?

            klass = +"(\e[4m#{error.class}\e[24m)"
            stage = +" [#{request.strategy.stage}]" if skip_base_class != StandardError

            +"\e[1m#{error.message} #{klass}#{stage}\e[0m\n#{steps.join("\n")}"
          end

          # Add new information to the table and update headers sizes
          def add_to_table(table, data)
            data = data.map(&:to_s)
            table[:header].each.with_index do |(header, size), idx|
              length = data[idx].length
              if length > COL_MAX_WIDTH
                table[:header][header] = COL_MAX_WIDTH
                data[idx] = data[idx][0..COL_MAX_WIDTH][0..-5] + '...'
              elsif length > size
                table[:header][header] = length
              end
            end

            table[:body] << data
          end

          # Build the string of the given table
          def stringify_table(table)
            sizes = table[:header].values
            headers = table[:header].keys

            # Add a little banner
            table[:body][-1][1] = "\e[1m\e[35m#{'GQL'.ljust(sizes[1])}\e[0m"

            # Build all the lines
            lines = table[:body].reverse.prepend(headers).map do |row|
              +' ' << row.map.with_index do |col, idx|
                col.ljust(sizes[idx])
              end.join(' | ') << ' '
            end

            # Add a divider between headers and values
            divider = sizes.map { |val| '-' * val }.join('-+-')
            divider = +'-' << divider << '-'
            lines.insert(1, divider)

            # Bold the header and join the lines
            lines[0] = +"\e[1m#{lines[0]}\e[0m"
            lines.join("\n")
          end

          # Better display records and other objects that might be to big to
          # show in here
          def print_object(object)
            object.respond_to?(:to_gql_backtrace) ? object.to_gql_backtrace : object.inspect
          end

          # Make sure to properly parse arguments and filter them
          def clean_arguments(arguments, request)
            value = arguments.as_json
            return '{}' if value.blank?

            request.cache(:backtrace_arguments_filter) do
              ActiveSupport::ParameterFilter.new(GraphQL.config.filter_parameters || [])
            end.filter(value)
          end

          # Visitors
          def row_for_field(data, item, suffix)
            field = item.field
            parent =
              if !field
                '*'
              elsif field.owner.is_a?(Helpers::WithSchemaFields)
                item.request.schema.type_name_for(field.schema_type)
              else
                field.owner.gql_name
              end

            name = +"#{parent}.#{field.gql_name}#{suffix}" unless field.nil?

            data.push(name || +"*.#{item.name}")
            data.push(nil, item.arguments, nil)
          end

          def row_for_fragment(data, item, *)
            type = item.instance_variable_get(:@node)[1]
            object = item.current_object || item.type_klass
            data.push(+"fragment #{item.name}", type, nil)
            data.push(print_object(object))
          end

          def row_for_operation(data, item, *)
            data.push(+"#{item.type} #{item.name}".squish)
            data.push('nil')
            data.push(item.variables)
            data.push(item.typename)
          end

          def row_for_spread(data, item, *)
            return false unless item.inline?

            type = item.instance_variable_get(:@node)[1]
            object = item.current_object || item.type_klass
            data.push('...', type, nil)
            data.push(print_object(object))
          end

          def row_for_schema(data, item, *)
            data.push('schema', item.namespace.inspect, nil, item.name)
          end

        private

          # The headers and sizes plus the rows for the table structure
          def begin_table
            {
              header: {
                ' ' => 1,
                'Loc' => 3,
                'Field' => 5,
                'Object' => 6,
                'Arguments' => 9,
                'Result' => 6,
              },
              body: [],
            }
          end

          # Find the class that will be responsible for cleaning the backtrace
          def cleaner
            LogSubscriber.backtrace_cleaner
          end

          # Rewrite the cleaner method so that it returns nil and do not clean
          # any of the items of the backtrace
          def show_everything!
            redefine_singleton_method(:cleaner) { nil }
          end
      end
    end
  end
end
