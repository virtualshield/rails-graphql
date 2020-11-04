# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This provides ways for fields to be resolved manually, by adding callbacks
    # and additional configurations in order to resolve a field value during a
    # request
    module Field::ResolvedField
      module Proxied # :nodoc: all
        def all_listeners
          field.all_listeners + super
        end

        def all_events
          events = defined?(@events) ? @events : {}
          Helpers.merge_hash_array(field.all_events, events).transform_values do |arr|
            arr.sort_by { |cb| cb.try(:target).is_a?(GraphQL::Field) ? 0 : 1 }
          end
        end

        def resolver
          super || field.resolver
        end

        def dynamic_resolver?
          super || field.dynamic_resolver?
        end
      end

      # Just add the callbacks setup to the field
      def self.included(other)
        other.include(Helpers::WithEvents)
        other.include(Helpers::WithCallbacks)
        other.event_types(:prepare, :finalize, expose: true)
        other.alias_method(:before_resolve, :prepare)
        other.alias_method(:after_resolve, :finalize)
      end

      # Add a block that is performed while resolving a value of a field
      def resolve(*args, **xargs, &block)
        @resolver = Callback.new(self, :resolve, *args, **xargs, &block)
      end

      # Get the resolver that can be already defined or used through the
      # +method_name+
      def resolver
        return unless dynamic_resolver?
        @resolver ||= Callback.new(self, :resolve, method_name)
      end

      # Check if the field has a dynamic resolver
      def dynamic_resolver?
        if defined?(@dynamic_resolver)
          @dynamic_resolver
        elsif defined?(@resolver)
          @resolver.present?
        else
          callable?(method_name)
        end
      end

      # Checks if all the named callbacks can actually be called
      def validate!(*)
        super if defined? super

        # Store this result for performance purposes
        @dynamic_resolver = dynamic_resolver?
        return unless defined? @events

        invalid = @events.each_value.reject do |callback|
          callback.block.is_a?(Proc) || callable?(callback.block)
        end

        raise ArgumentError, <<~MSG.squish if invalid.present?
          The "#{owner.name}" class does not define the following methods needed
          for performing hooks: #{invalid.map(&:block).to_sentence}.
        MSG
      end

      protected

        # Chedck if a given +method_name+ is callable from the owner perspective
        def callable?(method_name)
          owner.is_a?(Class) && owner.try(:gql_resolver?, method_name)
        end

        def proxied # :nodoc:
          super if defined? super
          extend Field::ResolvedField::Proxied
        end
    end

    Field::ScopedConfig.delegate :before_resolve, :after_resolve,
      :prepare, :finalize, :resolve, to: :field
  end
end
