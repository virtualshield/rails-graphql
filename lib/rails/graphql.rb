# frozen_string_literal: true

require 'active_model'
require 'active_support'

require 'active_support/core_ext/string/strip'

require 'rails/graphql/version'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'GraphiQL'
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
  # sometimes directives and fields:
  #
  # * <tt>Arguments:</tt> They are strictly associated with the object that
  #   defined it, also arguments with the same name doesn't mean they have the
  #   same behavior or configuration.
  # * <tt>Directives:</tt> A directive definition belongs to the introspection
  #   and is handled in the Singleton extent. They are handled as instance
  #   whenever a definition or an execution uses them.
  # * <tt>Fields:</tt> TODO: Finish explaining
  module GraphQL
    extend ActiveSupport::Autoload

    # Stores the version of the GraphQL spec used for this implementation
    SPEC_VERSION = 'June 2018'

    autoload :ToGQL
    autoload :Helpers
    autoload :Collectors

    eager_autoload do
      autoload :Core
      autoload :Event
      autoload :Native
      autoload :Request
      autoload :Source
      autoload :TypeMap

      autoload :Argument
      autoload :Callback
      autoload :Directive
      autoload :Field
      autoload :Mutation
      autoload :ProxyField
      autoload :Schema
      autoload :Type

      autoload :GraphiQL
      autoload :Introspection
    end

    class << self
      delegate :type_map, to: 'Rails::GraphQL::Core'

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
      # {Core}[rdoc-ref:Rails::GraphQL::Core] class.
      def set_configs!
        config.each { |k, v| Core.send "#{k}=", v }
      end

      ##
      # Turn the given object into its string representation as GraphQl
      # See {ToGQL}[rdoc-ref:Rails::GraphQL::ToGQL] class.
      def to_gql(object, **xargs)
        ToGQL.compile(object, **xargs)
      end

      alias to_graphql to_gql

      ##
      # Returns a set instance with uniq directives from the given list.
      # If the same directive class is given twice, it will raise an exception,
      # since they must be uniq within a list of directives.
      #
      # Use the others argument to provide a list of already defined directives
      # so the check can be performed using a +inherited_collection+.
      #
      # If a +source+ is provided, then an +:attach+ event will be triggered
      # for each directive on the givem source element.
      def directives_to_set(list, others = [], location: nil, source: nil)
        others = others.dup

        if source.present?
          event = GraphQL::Event.new(:attach, source, :definition)
          location ||= source.try(:directive_location)
        end

        Array.wrap(list).inject(Set.new) do |result, item|
          raise ArgumentError, <<~MSG.squish unless item.kind_of?(GraphQL::Directive)
            The "#{item.class}" is not a valid directive.
          MSG

          raise ArgumentError, <<~MSG.squish if (others.any? { |k| k.class.eql?(item.class) })
            A @#{item.gql_name} directive have already been provided.
          MSG

          invalid_location = location.present? && !item.locations.include?(location)
          raise ArgumentError, <<~MSG.squish if invalid_location
            You cannot use @#{item.gql_name} directive due to location restriction.
          MSG

          # event.trigger(item) unless event.nil?
          others << item
          result << item
        end
      end

      def eager_load! # :nodoc:
        super

        GraphQL::Request.eager_load!
        GraphQL::Source.eager_load!

        GraphQL::Directive.eager_load!
        GraphQL::Type.eager_load!
      end
    end
  end
end

require 'rails/graphql/errors'
require 'rails/graphql/shortcuts'
require 'rails/graphql/railtie'
