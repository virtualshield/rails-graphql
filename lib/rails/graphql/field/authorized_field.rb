# frozen_string_literal: true

module Rails
  module GraphQL
    # This provides ways for fields to be authorized, giving a logical level for
    # enabling or disabling access to a field. It has a similar structure to
    # events, but has a different hierarchy of resolution
    module Field::AuthorizedField
      module Proxied # :nodoc: all
        def authorizer
          super || field.authorizer
        end

        def authorizable?
          super || field.authorizable?
        end
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

      protected

        def proxied
          super if defined? super
          extend Field::AuthorizedField::Proxied
        end
    end
  end
end
