# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold directives during the=
      # defition process
      module WithDirectives
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.inherited_collection(:directives)
        end

        # Return the symbol that represents the location that the directives
        # must have in order to be added to the list
        def directive_location
          defined?(@directive_location) \
            ? @directive_location \
            : superclass.try(:directive_location)
        end

        # Use this once to define the directive location
        def directive_location=(value)
          # TODO: Change to a better exception type
          raise 'Directive location is already defined' unless directive_location.nil?
          @directive_location = value
        end

        # Use this method to assign directives to the given definition
        def use(*list)
          self.directives.merge list.each do |directive|
            # TODO: Replace this exception with a specific object
            raise <<~MSG.squish unless directive.locations.include?(directive_location)
              You cannot use @#{directive.gql_name} directive on #{gql_name} due to
              locations restriction.
            MSG
          end
        end
      end
    end
  end
end
