# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This provides ways for fields to be authorized, giving a logical level for
    # enabling or disabling access to a field. It has a similar structure to
    # events, but has a different hierarchy of resolution
    module Field::AuthorizedField
      # Just add the callbacks setup to the field
      def self.included(other)
        other.event_types(:authorize, append: true)
      end

      # Add either settings for authorization or a block to be executed. It
      # returns +self+ for chain purposes
      def authorize(*args, **xargs, &block)
        @authorizer = [args, xargs, block]
        self
      end

      # Return the settings for the authorize process
      def authorizer
        @authorizer if authorizable?
      end

      # Checks if the field should go through an authorization process
      def authorizable?
        defined?(@authorizer)
      end
    end
  end
end
#
