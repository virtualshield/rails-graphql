# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Mutation Field
    #
    # This is an extension of a normal output field, which just add extra
    # validation and ensurance that the +perform+ step can be executed
    #
    # ==== Options
    #
    # * <tt>:call</tt> - The alternative method to call to actually perform the mutation.
    #   (defaults to nil).
    class Field::MutationField < Field::OutputField
      redefine_singleton_method(:mutation?) { true }

      module Proxied # :nodoc: all
        def performer
          super || field.performer
        end
      end

      # Intercept the initializer to maybe set the +perform_method_name+
      def initialize(*args, call: nil, **xargs, &block)
        @perform_method_name = call.to_sym unless call.nil?
        super(*args, **xargs, &block)
      end

      # Accept changes to the perform method name through the +apply_changes+
      def apply_changes(**xargs, &block)
        @perform_method_name = xargs.delete(:call) if xargs.key?(:call)
        super
      end

      # Allows overrides for the default bang method
      def perform_method_name
        if defined?(@perform_method_name)
          @perform_method_name
        elsif from_alternative?
          :perform
        else
          :"#{method_name}!"
        end
      end

      # Change the schema type of the field
      def schema_type
        :mutation
      end

      # Add a block or a callable method that is executed before the resolver
      # but after all the before resolve. It returns +self+ for chain purposes
      def perform(*args, **xargs, &block)
        @performer = Callback.new(self, :perform, *args, **xargs, &block)
        self
      end

      # Get the performer that can be already defined or used through the
      # +method_name+ if that is callable
      def performer
        @performer ||= callable?(perform_method_name) \
          ? Callback.new(self, :perform, perform_method_name) \
          : false
      end

      # Ensures that the performer is defined
      def validate!(*)
        super if defined? super

        binding.pry unless performer.present?

        raise ValidationError, (+<<~MSG).squish unless performer.present?
          The "#{gql_name}" mutation field must have a perform action through a given
          block or a method named #{method_name} on #{owner.class.name}.
        MSG
      end

      protected

        def proxied
          super if defined? super
          extend Field::MutationField::Proxied
        end
    end

    Field::ScopedConfig.delegate :perform, to: :field
  end
end
