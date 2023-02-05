# frozen_string_literal: true

module Rails
  module GraphQL
    # This provides ways for fields to be resolved manually, by adding callbacks
    # and additional configurations in order to resolve a field value during a
    # request
    module Field::ResolvedField
      module Proxied # :nodoc: all
        def resolver
          super || field.resolver
        end

        def dynamic_resolver?
          super || field.dynamic_resolver?
        end
      end

      # Just add the callbacks setup to the field
      def self.included(other)
        other.send(:expose_events!, :organized, :finalize, :prepared, :prepare)
        other.alias_method(:before_resolve, :prepare)
        other.alias_method(:after_resolve, :finalize)
      end

      # Add a block that is performed while resolving a value of a field. It
      # returns +self+ for chain purposes
      def resolve(*args, **xargs, &block)
        @resolver = Callback.new(self, :resolve, *args, **xargs, &block)
        self
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
        return unless defined?(@events)

        # TODO: Change how events are validated. Relying on the +source_location
        # uses inspect, which is not a good approach

        # invalid = @events.each_pair.each_with_object({}) do |(key, events), hash|
        #   events.each do |event|
        #     _, method_name = event.source_location
        #     next if method_name.nil? || callable?(method_name)

        #     (hash[key] ||= []).push(method_name)
        #   end
        # end

        # return if invalid.empty?

        # invalid = invalid.map { |key, list| (+"#{key} => [#{list.join(', ')}]") }
        # raise ArgumentError, (+<<~MSG).squish if invalid.present?
        #   The "#{owner.name}" class does not define the following methods needed
        #   for performing callbacks: #{invalid.join(', ')}.
        # MSG
      end

      protected

        # Check if the method is defined and does not belong to a method defined
        # by the gem itself
        def callable?(method_name)
          owner.is_a?(Class) && owner.public_method_defined?(method_name) &&
            !owner.public_instance_method(method_name).owner.try(:abstract?)
        end

        def proxied
          super if defined? super
          extend Field::ResolvedField::Proxied
        end
    end

    Field::ScopedConfig.delegate :before_resolve, :after_resolve,
      :prepare, :finalize, :resolve, to: :field
  end
end
