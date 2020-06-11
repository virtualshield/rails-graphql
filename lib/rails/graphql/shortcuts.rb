# frozen_string_literal: true

# This exposed module allows some shortcuts while working outside of the gem
module GraphQL
  # List of constant shortcuts, as string to not trigger autoload
  CONST_SHORTCUTS = {
    Directive: '::Rails::GraphQL::Directive',
    Mutation:  '::Rails::GraphQL::Mutation',
    Request:   '::Rails::GraphQL::Request',
    Schema:    '::Rails::GraphQL::Schema',

    Enum:      '::Rails::GraphQL::Type::Enum',
    Input:     '::Rails::GraphQL::Type::Input',
    Interface: '::Rails::GraphQL::Type::Interface',
    Object:    '::Rails::GraphQL::Type::Object',
    Scalar:    '::Rails::GraphQL::Type::Scalar',
    Union:     '::Rails::GraphQL::Type::Union',
  }.freeze

  # List of directive shortcuts, which are basically the shortcut of another
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

    # See {Request}[rdoc-ref:Rails::GraphQL::Request]
    def request(*args)
      Rails::GraphQL::Request.new(*args)
    end

    # See {Request}[rdoc-ref:Rails::GraphQL::Request]
    def execute(*args)
      Rails::GraphQL::Request.execute(*args)
    end

    def const_defined?(name) # :nodoc:
      COSNT_SHORTCUTS.key?(name) || super
    end

    def const_missing(name) # :nodoc:
      CONST_SHORTCUTS[name]&.constantize || super
    end
  end
end
