# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      module InheritedCollection
        # Declare a class-level attribute whose value is both isolated and also
        # inherited from parent classes. Subclasses can change their own value
        # and it will not impact parent class.
        #
        # Inspired by +class_attribute+ from ActiveSupport.
        #
        # ==== Options
        #
        # * <tt>:singleton_writer</tt> - Sets the singleton writer method (defaults to false).
        # * <tt>:instance_reader</tt> - Sets the instance reader method (defaults to true).
        # * <tt>:instance_predicate</tt> - Sets a predicate method (defaults to true).
        # * <tt>:default</tt> - Sets a default value for the attribute (defaults to Set.new).
        #
        # ==== Examples
        #
        #   class Base
        #     inherited_collection :settings, singleton_writer: true
        #   end
        #
        #   class Subclass < Base
        #   end
        #
        #   Base.settings += [:a]
        #   Subclass.settings            # => []
        #   Subclass.all_settings        # => [:a]
        #   Subclass.settings += [:b]
        #   Subclass.settings            # => [:b]
        #   Subclass.all_settings        # => [:a, :b]
        #   Base.settings                # => [:a]
        #
        # By default, the writer is disable so the class cna implement a
        # specific method which will be used to assign the values. Using the
        # <tt>singleton_writer: true</tt> allows access to the assign method.
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
        #  To set a default value for the attribute, pass <tt>default:</tt>, like so:
        #
        #   class_attribute :settings, default: {}
        def inherited_collection(
          *attrs,
          singleton_writer: false,
          instance_reader: true,
          instance_predicate: true,
          default: Set.new
        )
          attrs.each do |name|
            ivar = "@#{name}"
            comb = default.is_a?(Hash) ? :merge : :+

            # TODO: Improve this method to be a lazy enumerator
            define_singleton_method("all_#{name}") do
              (superclass.try(name) || default.dup).send(comb, send(name))
            end

            define_singleton_method(name) do
              instance_variable_defined?(ivar) \
                ? instance_variable_get(ivar) \
                : instance_variable_set(ivar, default.dup)
            end

            define_singleton_method("#{name}?") do
              instance_variable_get(ivar).present? ||
                superclass.try(name).present?
            end if instance_predicate

            define_singleton_method("#{name}=") do |value|
              instance_variable_set(ivar, value)
            end if singleton_writer

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
