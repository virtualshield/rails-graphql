module Rails
  module GraphQL
    module Helpers
      # A inherited collection of Hash that can contain simple values, arrays,
      # or sets
      class InheritedCollection::Hash < InheritedCollection::Base
        delegate :transform_values, :transform_keys, to: :to_hash

        # Simply go over each definition and check for the given key
        def key?(value)
          each_definition.any? { |definition| definition.key?(value) }
        end

        # Collect all the keys of all the definitions
        def keys
          each_definition.reverse_each.flat_map(&:keys).uniq
        end

        # Go over each key and value
        def each
          Enumerator::Lazy.new(keys) do |yielder, key|
            val = self[key]
            yield(key, val) if block_given?
            yielder.yield(key, val)
          end
        end

        # Go over each value exclusively
        def each_value(&block)
          Enumerator::Lazy.new(keys) do |yielder, key|
            val = self[key]
            yield(val) if block_given?
            yielder.yield(val)
          end
        end

        # Go over each key exclusively
        def each_key(&block)
          keys.each(&block)
        end

        # Get all the values by lazy iterating over all the keys
        def values
          keys.lazy.map(&method(:[]))
        end

        # Basically allow this lazy operator to be merged with other hashes
        def to_hash
          each.to_h
        end

        # A simple way to get the result of one single key
        def [](key)
          lazy[key]
        end

        # Build a lazy hash
        def lazy
          @table ||= Hash.new(&method(_combine? ? :_combined_hash : :_simple_hash))
        end

        private

          # Check if it has to combine the values
          def _combine?
            @type != :hash
          end

          # Builds a values for a combined hash
          def _combined_hash(hash, key)
            hash[key] = each_definition.reverse_each.inject(nil) do |result, definition|
              next result unless definition.key?(key)
              next definition[key] if result.nil?
              result + definition[key]
            end
          end

          # Builds a values for a simple hash
          def _simple_hash(hash, key)
            hash[key] = each_definition.reverse_each do |definition|
              break definition[key] if definition.key?(key)
            end
          end
      end
    end
  end
end
