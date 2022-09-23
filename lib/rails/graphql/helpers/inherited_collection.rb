# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module that allow classes to have specific type of attributes
      # that are corretly delt when it is inherited by another class. It keeps
      # track of its own value and allow access to all values of the property
      # in the tree,
      #
      # TODO: Rewrite this!
      module InheritedCollection
        # All possible types of inheritable values
        DEFAULT_TYPES = {
          array:      '[]',
          set:        'Set.new',
          hash:       '{}',
          hash_array: '::Hash.new { |h, k| h[k] = [] }',
          hash_set:   '::Hash.new { |h, k| h[k] = Set.new }',
        }.freeze

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
            instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
              def all_#{name}
                return superclass.try(:all_#{name}) unless defined?(@#{name})
                InheritedCollection::Base.handle(self, :@#{name}, :#{type})
              end

              def #{name}
                @#{name} ||= #{DEFAULT_TYPES[type]}
              end
            RUBY

            instance_eval(<<~RUBY, __FILE__, __LINE__ + 1) if instance_predicate
              def #{name}?
                (defined?(@#{name}) && @#{name}.present?) || superclass.try(:#{name}?)
              end
            RUBY

            if instance_reader
              delegate(name.to_sym, :"all_#{name}", to: :class)
              delegate(:"#{name}?", to: :class) if instance_predicate
            end
          end
        end
      end
    end
  end
end

require_relative 'inherited_collection/base'

require_relative 'inherited_collection/array'
require_relative 'inherited_collection/hash'
