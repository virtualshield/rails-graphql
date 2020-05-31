# frozen_string_literal: true

# This exposed module allows some shortcuts while working outside of the gem
module GraphQL
  # List of constant shortcuts, as string to not trigger autoload
  COSNT_SHORTCUTS = {
    Directive: '::Rails::GraphQL::Directive',
    Enum:      '::Rails::GraphQL::Type::Enum',
    Input:     '::Rails::GraphQL::Type::Input',
    Interface: '::Rails::GraphQL::Type::Interface',
    Object:    '::Rails::GraphQL::Type::Object',
    Scalar:    '::Rails::GraphQL::Type::Scalar',
    Union:     '::Rails::GraphQL::Type::Union',
  }.freeze

  class << self
    delegate :to_gql, :to_graphql, to: ::Rails::GraphQL

    def const_missing(name) # :nodoc:
      COSNT_SHORTCUTS[name]&.constantize || super
    end
  end
end
