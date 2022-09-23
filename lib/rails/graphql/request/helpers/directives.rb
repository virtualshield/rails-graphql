# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper module to collect the directives from fragments, operations, and
      # fields.
      module Directives
        # Get the list of listeners from directives set during the request only
        def directive_listeners
          return unless directives?
          return @directive_listeners if defined?(@directive_listeners)
          @directive_listeners = directives.map(&:all_listeners).compact.reduce(:+)
        end

        alias all_listeners directive_listeners

        # Get the list of events from directives set during the request only and
        # then caches it by request
        def directive_events
          return unless directives?
          @directive_events ||= begin
            directives.map(&:all_events).compact.inject({}) do |lhash, rhash|
              Helpers.merge_hash_array(lhash, rhash)
            end
          end
        end

        alias all_events directive_events

        protected

          # Make sure to always return a set
          def directives
            @directives if directives?
          end

          # Check if any execution directive was added
          def directives?
            defined?(@directives)
          end

          # Helper parser for directives that also collect necessary variables
          def parse_directives(nodes, location = nil)
            return if nodes.nil?

            list = nil
            nodes.each do |(name, arguments)|
              instance = find_directive!(name.to_s)
              values = arguments&.each_with_object({}) do |(name, value, var_name), hash|
                hash[name.to_s] = var_name.nil? ? value : var_name
              end

              args = directive_arguments(instance)
              args = collect_arguments(args, values)

              (list ||= []) << instance.new(request.build(Request::Arguments, args))
            rescue ArgumentsError => error
              raise ArgumentsError, (+<<~MSG).squish
                Invalid arguments for @#{instance.gql_name} directive
                added to #{gql_name} #{kind}: #{error.message}.
              MSG
            end

            event = Event.new(:attach, strategy, self, phase: :execution)
            list = GraphQL.directives_to_set(list, [], event, location: location || kind)

            @directives = list.freeze
          end

          # Get and cache all the arguments for this given +directive+
          def directive_arguments(directive)
            request.nested_cache(:arguments, directive) do
              directive.all_arguments&.each_value&.with_object({}) do |directive, hash|
                hash[directive.gql_name] = directive
              end
            end
          end
      end
    end
  end
end
