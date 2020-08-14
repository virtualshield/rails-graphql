# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Output Field
    #
    # This is an extension of a normal output field, which just add extra
    # validation and ensurance that the +perform+ step can be executed
    class Field::MutationField < Field::OutputField
      module Proxied # :nodoc: all
        def performer
          super || field.performer
        end
      end

      # Add a block that is executed before the performer but after all the
      # before performer
      def perform(*args, **xargs, &block)
        @performer = Callback.new(self, :perform, *args, **xargs, &block)
      end

      # Get the performer that can be already defined or used through the
      # +method_name+
      def performer
        @performer ||= Callback.new(self, :perform, method_name)
      end

      # Ensures that the performer is defined
      def validate!(*)
        super if defined? super

        raise ValidationError, <<~MSG.squish if @performer.nil? && !callable?(method_name)
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
