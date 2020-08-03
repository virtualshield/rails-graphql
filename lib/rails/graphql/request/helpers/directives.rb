# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper module to collect the directives from fragments, operations, and
      # fields.
      module Directives
        DATA_PARTS = %i[directives]

        # Add the +directives+ to the list of data parts
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        # Get the list of listeners from all directives
        def all_listeners
          directives.map(&:all_listeners).reduce(:+) || Set.new
        end

        # Get the list of events from all directives and caches it by request
        def all_events
          @all_events ||= directives.map(&:all_events).inject({}) do |lhash, rhash|
            Helpers::InheritedCollection.merge_hash_array!(lhash, rhash)
          end
        end

        protected
          # Make sure to always return a set
          def directives
            @directives || Set.new
          end

          alias all_directives directives

          # Helper parser for directives that also collect necessary variables
          def parse_directives(location = nil)
            list = []

            visitor.collect_directives(*data[:directives]) do |data|
              # TODO: Add request cache
              # TODO: Share this behavior of argument/variable assignment
              instance = find_directive!(data[:name])

              parser = instance.all_arguments
              parser = parser.map(&:gql_name).zip(parser.values).to_h

              args = data[:arguments].map do |key, value|
                raise ArgumentError, <<~MSG.squish unless parser.key?(key)
                  The "#{instance.gql_name}" directive does not contain a
                  "#{arg_name}" argument.
                MSG

                parse_directive_argument(parser[key], value)
              end.to_h

              list << instance.new(request.build(Request::Arguments, args))
            end unless data[:directives].empty?

            if list.present?
              event = Event.new(:attach, strategy, self, phase: :execution)
              list = GraphQL.directives_to_set(list, [], event, location: location || kind)
            end

            @directives = list.freeze
          end

          # If the value is a pointer, then it needs to collect a variable from
          # the operation level, otherwise, return the value without changes
          def parse_directive_argument(argument, value)
            return value unless value.is_a?(::FFI::Pointer)

            raise ArgumentError, <<~MSG.squish unless respond_to?(:variables)
              Unable to use variable "$#{var_name}" in the current scope.
            MSG

            variables[visitor.node_name(value)]
          end
      end
    end
  end
end
