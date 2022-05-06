# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper module to collect the directives from fragments, operations, and
      # fields.
      module Directives
        # Get the list of listeners from directives set during the request only
        def all_listeners
          directives.map(&:all_listeners).reduce(:+) || Set.new
        end

        # Get the list of events from directives set during the request only and
        # then caches it by request
        def all_events
          @all_events ||= directives.map(&:all_events).inject({}) do |lhash, rhash|
            Helpers.merge_hash_array(lhash, rhash)
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
              instance = find_directive!(data[:name])

              args = directive_arguments(instance)
              args = collect_arguments(args, data[:arguments]) do |errors|
                "Invalid arguments for @#{instance.gql_name} directive" \
                  " added to #{gql_name} #{kind}: #{errors}."
              end

              list << instance.new(request.build(Request::Arguments, args))
            end unless data[:directives].blank?

            if list.present?
              event = Event.new(:attach, strategy, self, phase: :execution)
              list = GraphQL.directives_to_set(list, [], event, location: location || kind)
            end

            @directives = list.freeze
          end

          # Get and cache all the arguments for this given +directive+
          def directive_arguments(directive)
            request.cache(:arguments)[directive] ||= begin
              result = directive.all_arguments
              result.each_value.map(&:gql_name).zip(result.each_value).to_h
            end
          end
      end
    end
  end
end
