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

  # List of directive shortcuts, which are basically the shjortcut of another
  # shortcut to instantiate a directive.
  #
  # ==== Examples
  #
  #   GraphQL::DeprecatedDirective(...)
  #   # => Rails::GraphQL::Directive::DeprecatedDirective(...)
  #
  #   Rails::GraphQL::Directive::DeprecatedDirective(...)
  #   # => Rails::GraphQL::Directive::DeprecatedDirective.new(...)
  DIRECTIVE_SHORTCUTS = %i[DeprecatedDirective IncludeDirective SkipDirective]

  class << self
    delegate :to_gql, :to_graphql, :type_map, to: 'Rails::GraphQL'
    delegate *DIRECTIVE_SHORTCUTS, to: 'Rails::GraphQL::Directive'

    def const_missing(name) # :nodoc:
      COSNT_SHORTCUTS[name]&.constantize || super
    end
  end
end
