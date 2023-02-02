# frozen_string_literal: true

module Rails
  module GraphQL
    module Subscription
      module Store
        # = GraphQL Memory Subscription Store
        #
        # This store will save all the subscriptions in a very similar way that
        # the TypeMap works, using nested concurrent maps that points out to
        # them. Everything is based on the sid of the subscription
        class Memory < Base
          attr_reader :list, :index

          def initialize
            # The list store a simple association between sid and
            @list = Concurrent::Map.new

            # This store the index in a way that is possible to search
            # subscriptions in a fast manner
            @index = Concurrent::Map.new do |h1, key1|               # Fields
              scopes = Concurrent::Map.new do |h2, key2|             # Scopes
                arguments = Concurrent::Map.new do |h3, key3|        # Arguments
                  h3.fetch_or_store(key3, Concurrent::Array.new)     # SIDs
                end

                h2.fetch_or_store(key2, arguments)
              end

              h1.fetch_or_store(key1, scopes)
            end
          end

          def serialize(**xargs)
            return xargs if !xargs.key?(:field) || xargs[:field].is_a?(Numeric)

            xargs[:field] = hash_for(xargs[:field])
            xargs[:scope] = possible_scopes(xargs[:scope])
            xargs[:args] = Array.wrap(xargs[:args]).map(&method(:hash_for))
            xargs
          end

          def all
            list.keys
          end

          def add(subscription)
            if has?(subscription.sid)
              raise ::ArgumentError, +"SID #{subscription.sid} is already taken."
            end

            # Rewrite the scope, to save memory
            scope = possible_scopes(subscription.scope)&.first
            subscription.instance_variable_set(:@scope, scope)

            # Save to the list and to the index
            list[subscription.sid] = subscription
            index_set = subscription_to_index(subscription).reduce(index, &:[])
            index_set << subscription.sid
            subscription.sid
          end

          def fetch(*sids)
            return if sids.none?

            items = sids.map do |item|
              instance?(item) ? item : list[item]
            end

            items.one? ? items.first : items
          end

          def remove(item)
            return unless has?(item)

            instance = instance?(item) ? item : fetch(item)
            path = subscription_to_index(instance)
            index.delete(instance.sid)

            f_level = index[path[0]]
            s_level = f_level[path[1]]
            a_level = s_level[path[2]]

            a_level.delete(instance.sid)
            s_level.delete(path[2]) if a_level.empty?
            f_level.delete(path[1]) if s_level.empty?
            index.delete(path[0]) if f_level.empty?
          end

          def update!(item)
            (instance?(item) ? item : fetch(item)).update!
          end

          def has?(item)
            list.key?(instance?(item) ? item.sid : item)
          end

          def search(**xargs, &block)
            xargs = serialize(**xargs)
            field, scope, args = xargs.values_at(:field, :scope, :args)

            if field.nil? && args.nil? && scope.nil?
              list.each(&block) unless block.nil?
              return all
            end

            [].tap do |result|
              GraphQL.enumerate(field || index.keys).each do |key1|
                GraphQL.enumerate(scope || index[key1].keys).each do |key2|
                  GraphQL.enumerate(args || index[key2].keys).each do |key3|
                    items = index.fetch(key1, nil)&.fetch(key2, nil)&.fetch(key3, nil)
                    items.each(&list.method(:[])).each(&block) unless block.nil?
                    result.concat(items || EMPTY_ARRAY)
                  end
                end
              end
            end
          end

          alias find_each search

          protected

            # Turn the request subscription into into the path of the index
            def subscription_to_index(subscription)
              [
                subscription.field.hash,
                subscription.scope,
                subscription.args.hash,
              ]
            end
        end
      end
    end
  end
end
