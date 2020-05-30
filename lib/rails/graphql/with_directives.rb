# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Marks that a given object accepts being defined with a set of directives
    module WithDirectives
      # Use this method one single time per extension to specify the
      # directive location
      class_attribute :directive_location, instance_writer: false

      # Return the list of directives associated with the definition of an
      # object
      def directives
        _directives + (superclass.try(:directives) || [])
      end

      # Use this method to assign directives to the given definition
      def use(*directives)
        _directives += directives.each do |directive|
          # TODO: Replace this exception with a specific object
          raise <<~MSG.squish unless directive.locations.include?(directive_location)
            You cannot use @#{directive.gql_name} directive on #{gql_name} due to
            locations restriction.
          MSG
        end
      end

      private

        # Get the internal object with the list of directives
        def _directives
          @directives ||= Set.new
        end
    end
  end
end
