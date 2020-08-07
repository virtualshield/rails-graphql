# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      module InheritedCollection
        DEFAULT_TYPES = {
          array:      '[]',
          set:        '[].to_set',
          hash:       '{}',
          hash_array: 'Hash.new { |h, k| h[k] = [] }',
        }.freeze

        # Support class for a lazy value processing. The values will be
        # collected once the underling reference is actually used
        class LazyValue < ActiveSupport::ProxyObject
          delegate_missing_to :__target_object__

          def initialize(&callable)
            @callable = callable
          end

          def __target_object__
            @target_object ||= @callable.call
          end
        end

        # Global helper that merge a hash that contains values as arrays
        def self.merge_hash_array(one, other)
          one.merge(other) { |_, lval, rval| lval + rval }
        end

        # Declare a class-level attribute whose value is both isolated and also
        # inherited from parent classes. Subclasses can change their own value
        # and it will not impact parent class.
        #
        # Inspired by +class_attribute+ from ActiveSupport.
        #
        # ==== Options
        #
        # * <tt>:instance_reader</tt> - Sets the instance reader method (defaults to true).
        # * <tt>:instance_predicate</tt> - Sets a predicate method (defaults to true).
        # * <tt>:type</tt> - Defines the type of the values stored (defaults to :set).
        #
        # ==== Examples
        #
        #   class Base
        #     inherited_collection :settings
        #   end
        #
        #   class Subclass < Base
        #   end
        #
        #   Base.settings << :a
        #   Subclass.settings            # => []
        #   Subclass.all_settings        # => [:a]
        #   Subclass.settings << :b
        #   Subclass.settings            # => [:b]
        #   Subclass.all_settings        # => [:a, :b]
        #   Base.settings                # => [:a]
        #   Base.all_settings            # => [:a]
        #
        # For convenience, an instance predicate method is defined as well,
        # which checks for the +all_+ method. To skip it, pass
        # <tt>instance_predicate: false</tt>.
        #
        #   Subclass.settings?       # => false
        #
        # To opt out of the instance reader method, pass <tt>instance_reader: false</tt>.
        #
        #   object.settings          # => NoMethodError
        #   object.settings?         # => NoMethodError
        #
        def inherited_collection(
          *attrs,
          instance_reader: true,
          instance_predicate: true,
          type: :set
        )
          attrs.each do |name|
            ivar = "@#{name}"

            module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
              def self.all_#{name}
                ::Rails::GraphQL::Helpers::InheritedCollection::LazyValue.new do
                  defined?(:#{ivar}) \
                    ? fetch_inherited_#{type}('#{ivar}') \
                    : #{DEFAULT_TYPES[type]}
                end
              end

              def self.#{name}
                #{ivar} ||= #{DEFAULT_TYPES[type]}
              end
            RUBY

            module_eval(<<~RUBY, __FILE__, __LINE__ + 1) if instance_predicate
              def self.#{name}?
                #{ivar}.present? || superclass.try(:#{name}?)
              end
            RUBY

            if instance_reader
              delegate(name.to_sym, :"all_#{name}", to: :class)
              delegate(:"#{name}?", to: :class) if instance_predicate
            end
          end
        end

        protected

          # Combine an inherited list of arrays
          def fetch_inherited_array(ivar)
            inherited_ancestors.inject([]) do |result, klass|
              val = klass.instance_variable_get(ivar)
              val.nil? ? result : result += val
            end
          end

          # Combine an inherited list of set objects
          def fetch_inherited_set(ivar)
            inherited_ancestors.inject(Set.new) do |result, klass|
              val = klass.instance_variable_get(ivar)
              val.nil? ? result : result += val
            end
          end

          # Combine an inherited list of hashes but keeping only the most recent
          # value, which means that keys might be replaced
          def fetch_inherited_hash(ivar)
            inherited_ancestors.inject({}) do |result, klass|
              val = klass.instance_variable_get(ivar)
              val.nil? ? result : result.merge(val)
            end
          end

          # Combine an inherited list of hashes, which also will combine arrays,
          # ensuring that same key items will be combined
          def fetch_inherited_hash_array(ivar)
            inherited_ancestors.inject({}) do |result, klass|
              next result if (val = klass.instance_variable_get(ivar)).nil?
              InheritedCollection.merge_hash_array(result, val)
            end
          end

        private

          # Return a list of all the ancestor classes up until object
          def inherited_ancestors
            @inherited_ancestors ||= [self].tap do |list|
              list.unshift(list.first.superclass) \
                until list.first.superclass === Object
            end
          end
      end
    end
  end
end
