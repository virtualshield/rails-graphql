# frozen_string_literal: true

require 'active_support/core_ext/module/anonymous'

module Rails
  module GraphQL
    module Helpers
      # Helper module responsible for name stuff
      module WithName
        NAME_EXP = /GraphQL::(?:Type::\w+::|Directive::)?([:\w]+?)([A-Z][a-z]+)?\z/.freeze

        # Here we define a couple of attributes used by registration
        def self.extended(other)
          # An abstract type won't appear in the introspection and will not be
          # instantiated by requests
          other.class_attribute :abstract, instance_accessor: false, default: false

          # The given description of the element
          other.class_attribute :description, instance_writer: false
        end

        # Return the name of the object as a GraphQL name
        def gql_name
          @gql_name ||= begin
            name.match(NAME_EXP).try(:[], 1)&.tr(':', '')
          end unless anonymous?
        end

        alias graphql_name gql_name

        # Return the name of the object as a symbol
        def to_sym
          @gql_key ||= gql_name&.underscore&.to_sym
        end

        protected

          # An alias for +description = value.strip_heredoc.chomp+ that can be
          # used as method
          def desc(value)
            self.description = value.strip_heredoc.chomp
          end

          # Change the gql name of the object
          def rename!(name)
            @gql_name = name.to_s
          end
      end
    end
  end
end
