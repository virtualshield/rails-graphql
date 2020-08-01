# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This provides ways for fields to be resolved manually, by adding callbacks
    # and additional configurations in order to resolve a field value during a
    # request
    module Field::ResolvedField
      include Helpers::WithEvents
      include Helpers::WithCallbacks

      event_types %i[prepare finalize]
      expose_events!

      alias before_resolve prepare
      alias after_resolve finalize

      # Just add the callbacks setup to the field
      def self.included(other)
        other.extend(Helpers::WithCallbacks::Setup)
      end

      # If the field has a resolver, then it can't be serialized from Active
      # Record
      def from_ar?(*)
        dynamic_resolver? ? false : super
      end

      # If the field has a resolver, then it can't be serialized from Active
      # Record
      def from_ar(*)
        dynamic_resolver? ? false : super
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
        @resolver.present? || callable?(method_name)
      end

      # Checks if all the named callbacks can actually be called
      def validate!(*)
        super if defined? super

        invalid = events.each_value.reject do |callback|
          callback.block.is_a?(Proc) || callable?(callback.block)
        end

        raise ArgumentError, <<~MSG.squish if invalid.present?
          The "#{owner.name}" class does not define the following methods needed
          for performing hooks: #{invalid.map(&:block).to_sentence}.
        MSG

        nil # No exception already means valid
      end

      protected

        # Chedck if a given +method_name+ is callable from the owner perspective
        def callable?(method_name)
          owner.is_a?(Class) && owner.try(:gql_resolver?, method_name)
        end
    end

    Field::ScopedConfig.delegate :before_resolve, :after_resolve,
      :prepare, :finalize, :resolve, to: :field
  end
end
