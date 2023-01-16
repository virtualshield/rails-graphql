# frozen_string_literal: true

module Rails
  module GraphQL
    module Subscription
      module Store
        # = GraphQL Base Subscription Store
        #
        # The base class for all the other subscription stores, which defines
        # the necessary interfaces to keep track of all the subscriptions
        #
        # Be careful with each subscription context. Although there are ways to
        # clean it up (by implementing a +subscription_context+ callback into
        # the field), it is still the most dangerous and heavy object that can
        # be placed into the store. The problem with in memory store is that it
        # does not work with a Rails application running cross-processes. On the
        # other hand, file, Redis, or Database-based stores can find it
        # difficult to save the context and bring it back to Rails again
        #
        # The closest best way to be safe about the context is relying on
        # +ActiveJob::Arguments+ to serialize and deserialize it (which aligns
        # with all possible arguments that jobs and receive and how they are
        # usually properly stored in several different providers for ActiveJob)
        class Base
          # An abstract type won't appear in the introspection and will not be
          # instantiated by requests
          class_attribute :abstract, instance_accessor: false, default: false

          class << self

            # Make sure that abstract classes cannot be instantiated
            def new(*)
              return super unless self.abstract

              raise StandardError, (+<<~MSG).squish
                #{name} is abstract and cannot be used as a subscription store.
              MSG
            end

          end

          # Get the list of provided +xargs+ for search and serialize them
          def serialize(**xargs)
            xargs
          end

          # Return all the sids stored
          def all
            raise NotImplementedError, +"#{self.class.name} does not implement all"
          end

          # Add a new subscription to the store, saving in a way it can be easily
          # searched at any point
          def add(subscription)
            raise NotImplementedError, +"#{self.class.name} does not implement add"
          end

          # Fetch one or more subscriptions by their ids
          def fetch(*sids)
            raise NotImplementedError, +"#{self.class.name} does not implement fetch"
          end

          # Remove a given subscription from the store by its id or instance
          def remove(item)
            raise NotImplementedError, +"#{self.class.name} does not implement remove"
          end

          # Check if a given sid or instance is stored
          def has?(item)
            raise NotImplementedError, +"#{self.class.name} does not implement has?"
          end

          # Search one or more subscriptions by the list of provided options and
          # return the list of sids that matched. A block can be provided to go
          # through each of the found results, yield the object itself instead
          # of the sid
          def search(**options, &block)
            raise NotImplementedError, +"#{self.class.name} does not implement search"
          end

          alias find_each search

          protected

            # Check if the given +object+ is a subscription instance
            def instance?(object)
              object.is_a?(Request::Subscription)
            end

            # Transform a scope in several possible scopes, as in:
            #   nil => nil
            #   :user => [[:user]]
            #   User.find(1) => [[NNN1]] # .hash
            #   [User.find(1), :sample] => [[NNN1, :sample]]
            #   { User => 1, other: :profile } => [[NNN1, :profile]]
            #   { User => [1, 2], other: :profile } => [[NNN1, :profile], [NNN2, :profile]]
            def possible_scopes(scope)
              return if scope.nil? || scope === EMPTY_ARRAY

              list = Array.wrap(scope).each_with_object([]) do |value, result|
                result << options = []

                next GraphQL.enumerate(value).each do |val|
                  options << hash_for(val)
                end unless value.is_a?(Hash)

                value.each.with_index do |(key, sub_value), idx|
                  result << options = [] if idx > 0

                  klass_arg = key if key.is_a?(Class)
                  GraphQL.enumerate(sub_value).each do |val|
                    options << hash_for(val, klass_arg)
                  end
                end
              end

              list.reduce(:product).flatten.each_slice(list.size).map { |a| a.reduce(:^) }
            end

            # By default, get the hash of the value. If class is provided, add
            # it as part of the hash (similar to how ActiveRecord calculates
            # the hash for a model's record)
            def hash_for(value, klass = nil)
              if !klass.nil?
                klass.hash ^ value.hash
              elsif extract_class_from?(value)
                value.class.hash ^ value.id.hash
              elsif value.is_a?(Numeric)
                value
              else
                value.hash
              end
            end

            # Check if ActiveRecord::Base is available and then if the object
            # provided is an instance of it, so that the serialize can work
            # correctly
            def extract_class_from?(value)
              defined?(ActiveRecord) && value.is_a?(ActiveRecord::Base)
            end
        end
      end
    end
  end
end
