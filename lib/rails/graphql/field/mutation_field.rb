# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Output Field
    #
    # This is an extension of a normal output field, which just add extra
    # validation and ensurance that the +perform+ step can be executed
    class Field::MutationField < Field::OutputField
      redefine_singleton_method(:mutation?) { true }

      module Proxied # :nodoc: all
        def performer
          super || field.performer
        end
      end

      # Add a block or a callable method that is executed before the resolver
      # but after all the before resolve
      def perform(*args, **xargs, &block)
        @performer = Callback.new(self, :perform, *args, **xargs, &block)
      end

      # Get the performer that can be already defined or used through the
      # +method_name+ if that is callable
      def performer
        @performer ||= callable?(:"#{method_name}!") \
          ? Callback.new(self, :perform, :"#{method_name}!") \
          : false
      end

      # Ensures that the performer is defined
      def validate!(*)
        super if defined? super

        raise ValidationError, <<~MSG.squish unless performer.present?
          The "#{gql_name}" mutation field must have a perform action through a given
          block or a method named #{method_name} on #{owner.class.name}.
        MSG
      end

      protected

        def proxied # :nodoc:
          super if defined? super
          extend Field::MutationField::Proxied
        end
    end

    Field::ScopedConfig.delegate :perform, to: :field
  end
end
