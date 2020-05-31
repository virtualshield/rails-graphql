# frozen_string_literal: true

require 'active_model'
require 'active_support'
require 'active_support/core_ext/class/subclasses'

require 'rails/graphql/version'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'GraphQL'
  inflect.acronym 'GQLAst'
end

module Rails # :nodoc:
  # = Rails GraphQL
  #
  # This implementation tries to be as close as the GraphQL spec as possible,
  # meaning that this lib shares most of the same names and directions provided
  # by the GraphQL spec. You can use {Rails::GraphQL::SPEC_VERSION}[rdoc-ref:Rails::GraphQL]
  # to check which spec is being sued.
  #
  # Using ActiveSupport, define all the needed objects but doesn't load them
  # since it's better to trust on eager_load in order to proper load the objects.
  #
  # A very important concept is that Singleton definitions are a direct
  # connection to a {GraphQL Introspection}[http://spec.graphql.org/June2018/#sec-Introspection],
  # meaning that to query the introspection is to query everything defined and
  # associated with the GraphQL objects, the only exception are arguments and
  # directives.
  #
  # TODO: In order to have a multi-introspection result on the same application,
  # whe should implement a *namespace* concept
  module GraphQL
    extend ActiveSupport::Autoload

    # Stores the version of the GraphQL spec used for this implementation
    SPEC_VERSION = 'June 2018'

    autoload :ToGQL
    autoload :Helpers

    eager_autoload do
      autoload :Core
      autoload :Native
      autoload :NamedDefinition
      autoload :WithDirectives

      autoload :Argument
      autoload :Directive
      autoload :Schema
      autoload :Type

      autoload :GraphiQL
    end

    class << self
      ##
      # Initiate a simple config object. It also supports a block which
      # simplifies bulk configuration.
      # See Also https://github.com/rails/rails/blob/master/activesupport/lib/active_support/ordered_options.rb
      def config
        @config ||= begin
          config = ActiveSupport::OrderedOptions.new
          config.graphiql = ActiveSupport::OrderedOptions.new
          config
        end

        yield(@config) if block_given?

        @config
      end

      ##
      # Simple import configurations defined using rails +config.graphql+ to
      # easy-to-use accessors on the
      # {Schema}[rdoc-ref:Rails::GraphQL::Core] class.
      def set_configs!
        config.each { |k, v| Core.send "#{k}=", v }
      end

      # See {ToGQL}[rdoc-ref:Rails::GraphQL::Type] class.
      def find_input_type(thing)
        GraphQL::Type.find_input(thing)
      end

      # See {ToGQL}[rdoc-ref:Rails::GraphQL::Type] class.
      def find_output_type(thing)
        GraphQL::Type.find_output(thing)
      end

      ##
      # Turn the given object into its string representation as GraphQl
      # See {ToGQL}[rdoc-ref:Rails::GraphQL::ToGQL] class.
      def to_gql(object, **xargs)
        ToGQL.compile(object, **xargs)
      end

      alias to_graphql to_gql
    end
  end
end

require 'rails/graphql/railtie'
