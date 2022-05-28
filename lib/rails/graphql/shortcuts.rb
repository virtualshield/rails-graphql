# frozen_string_literal: true

# This exposed module allows some shortcuts while working outside of the gem
module GraphQL
  # List of constant shortcuts, as string to not trigger autoload
  CONST_SHORTCUTS = {
    CacheKey:           '::Rails::GraphQL::CacheKey',
    Controller:         '::Rails::GraphQL::Controller',
    Directive:          '::Rails::GraphQL::Directive',
    Field:              '::Rails::GraphQL::Field',
    GlobalID:           '::Rails::GraphQL::GlobalID',
    Request:            '::Rails::GraphQL::Request',
    Schema:             '::Rails::GraphQL::Schema',
    Source:             '::Rails::GraphQL::Source',
    Type:               '::Rails::GraphQL::Type',

    Query:              '::Rails::GraphQL::Alternative::Query',
    Mutation:           '::Rails::GraphQL::Alternative::Mutation',
    Subscription:       '::Rails::GraphQL::Alternative::Subscription',

    Enum:               '::Rails::GraphQL::Type::Enum',
    Input:              '::Rails::GraphQL::Type::Input',
    Interface:          '::Rails::GraphQL::Type::Interface',
    Object:             '::Rails::GraphQL::Type::Object',
    Scalar:             '::Rails::GraphQL::Type::Scalar',
    Union:              '::Rails::GraphQL::Type::Union',

    ProxyField:         '::Rails::GraphQL::Field::ProxyField',
    AssociationField:   '::Rails::GraphQL::Field::AssociationField',

    ActiveRecordSource: '::Rails::GraphQL::Source::ActiveRecordSource',
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
  DIRECTIVE_SHORTCUTS = %i[DeprecatedDirective IncludeDirective SkipDirective].freeze

  class << self
    delegate(:to_gql, :to_graphql, :type_map, to: 'Rails::GraphQL')
    delegate(*DIRECTIVE_SHORTCUTS, to: 'Rails::GraphQL::Directive')

    # See {Request}[rdoc-ref:Rails::GraphQL::Request]
    def request(*args, **xargs)
      Rails::GraphQL::Request.new(*args, **xargs)
    end

    # See {Request}[rdoc-ref:Rails::GraphQL::Request]
    def execute(*args, **xargs)
      Rails::GraphQL::Request.execute(*args, **xargs)
    end

    alias perform execute

    # See {CONST_SHORTCUTS}[rdoc-ref:GraphQL::CONST_SHORTCUTS]
    def const_defined?(name, *)
      name = :"ActiveRecord#{name[2..-1]}" if name[0..1] === 'AR'
      CONST_SHORTCUTS.key?(name) || super
    end

    # See {CONST_SHORTCUTS}[rdoc-ref:GraphQL::CONST_SHORTCUTS]
    def const_missing(name)
      name = :"ActiveRecord#{name[2..-1]}" if name[0..1] === 'AR'
      return resolved[name] if resolved.key?(name)
      return super unless CONST_SHORTCUTS.key?(name)
      resolved[name] = CONST_SHORTCUTS[name].constantize
    end

    private

      # Stores resolved constants for increased performance
      def resolved
        @@resolved = {}
      end
  end
end
