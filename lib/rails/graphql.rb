# frozen_string_literal: true

require 'i18n'
require 'zlib'
require 'active_model'
require 'active_support'

require 'active_support/core_ext/module/attribute_accessors_per_thread'
require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/enumerable'

require 'rails/graphql/version'
require 'rails/graphql/uri'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'GraphiQL'
  inflect.acronym 'GraphQL'
  inflect.acronym 'URL'
end

module Rails
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
  # associated with the GraphQL objects, the only exception are arguments,
  # directives and fields:
  #
  # * <tt>Arguments:</tt> They are strictly associated with the object that
  #   defined it, also arguments with the same name doesn't mean they have the
  #   same behavior or configuration.
  # * <tt>Directives:</tt> A directive definition belongs to the introspection
  #   and is handled in the Singleton extent. They are handled as instance
  #   whenever a definition or an execution uses them.
  # * <tt>Fields:</tt> Many other types and helper containers holds a series of
  #   fields, which means that fields with the same name will probably behave
  #   differently.
  module GraphQL
    extend ActiveSupport::Autoload

    include ActiveSupport::Configurable

    # Stores the version of the GraphQL spec used for this implementation
    SPEC_VERSION = ::GQLParser::VERSION

    # Just a reusable instances of an empty array and empty hash
    EMPTY_ARRAY = [].freeze
    EMPTY_HASH = {}.freeze

    # Runtime registry for request execution time
    RuntimeRegistry = Class.new { thread_mattr_accessor :gql_runtime }

    # Helper class to produce a ActiveSupport-compatible versioned cache key
    CacheKey = Struct.new(:cache_key, :cache_version) do
      def inspect
        cache_version ? +"#{cache_key}[#{cache_version}]" : cache_key
      end
    end

    autoload :ToGQL
    autoload :Event
    autoload :Source
    autoload :Helpers
    autoload :Callback
    autoload :GlobalID
    autoload :Collectors
    autoload :Alternative
    autoload :Subscription
    autoload :Shared
    autoload :Service

    autoload :Argument
    autoload :Directive
    autoload :Field
    autoload :Introspection
    autoload :Schema
    autoload :Type

    autoload_under :railties do
      autoload :BaseGenerator
      autoload :Channel
      autoload :Controller
      autoload :ControllerRuntime
      autoload :LogSubscriber
    end

    eager_autoload do
      autoload :TypeMap
      autoload :Request
    end

    class << self
      # Access to the type mapper
      def type_map
        @@type_map ||= GraphQL::TypeMap.new
      end

      # Find the key associated with the given +adapter_name+
      def ar_adapter_key(adapter_name)
        config.ar_adapters.dig(adapter_name, :key)
      end

      # This is a little helper to require ActiveRecord adapter specific
      # configurations
      def enable_ar_adapter(adapter_name)
        return if (@@loaded_adapters ||= Set.new).include?(adapter_name)

        raise ::ArgumentError, (+<<~MSG).squish unless config.ar_adapters.key?(adapter_name)
          There is no GraphQL mapping for #{adapter_name} ActiveRecord adapter.
        MSG

        require(config.ar_adapters.dig(adapter_name, :path))
        @@loaded_adapters << adapter_name
      end

      # Due to reloader process, adapter settings need to be reloaded
      def reload_ar_adapters!
        return unless defined?(@@loaded_adapters)
        adapters, @@loaded_adapters = @@loaded_adapters, Set.new
        adapters.map(&method(:enable_ar_adapter))
      end

      # Turn the given object into its string representation as GraphQl
      # See {ToGQL}[rdoc-ref:Rails::GraphQL::ToGQL] class.
      def to_gql(object, **xargs)
        ToGQL.compile(object, **xargs)
      end

      alias to_graphql to_gql

      # A generic helper to not create a new array when just iterating over
      # something that may or may not be an array
      def enumerate(value)
        (value.is_a?(Enumerable) || value.respond_to?(:to_ary)) ? value : value.then
      end

      # Load a given +list+ of dependencies from the given +type+
      def add_dependencies(type, *list, to: :base)
        ref = config.known_dependencies

        raise ArgumentError, (+<<~MSG).squish if (ref = ref[type]).nil?
          There are no #{type} known dependencies.
        MSG

        list = list.flatten.compact.map do |item|
          next item unless (item = ref[item]).nil?
          raise ArgumentError, (+<<~MSG).squish
            Unable to find #{item} as #{type} in known dependencies.
          MSG
        end

        type_map.add_dependencies(list, to: to)
      end

      # Returns a set instance with uniq directives from the given list.
      # If the same directive class is given twice, it will raise an exception,
      # since they must be uniq within a list of directives.
      #
      # Use the others argument to provide a list of already defined directives
      # so the check can be performed using a +inherited_collection+.
      #
      # If a +source+ is provided, then an +:attach+ event will be triggered
      # for each directive on the given source element.
      def directives_to_set(list, others = nil, event = nil, **xargs)
        return if list.blank?

        if (source = xargs.delete(:source)).present?
          location = xargs.delete(:location) || source.try(:directive_location)
          event ||= GraphQL::Event.new(:attach, source, phase: :definition, **xargs)
        end

        others = others&.to_set
        enumerate(list).each_with_object(Set.new) do |item, result|
          raise ArgumentError, (+<<~MSG).squish unless item.kind_of?(GraphQL::Directive)
            The "#{item.class}" is not a valid directive.
          MSG

          check_location = location.present? && !item.locations.include?(location)
          raise ArgumentError, (+<<~MSG).squish if check_location
            You cannot use @#{item.gql_name} directive due to location restriction.
          MSG

          check_uniqueness = !item.repeatable? && (others&.any?(item) || result.any?(item))
          raise DuplicatedError, (+<<~MSG).squish if check_uniqueness
            A @#{item.gql_name} directive have already been provided.
          MSG

          unless event.nil?
            begin
              item.assign_owner!(event.source)
              event.trigger_object(item)
              item.validate!
            rescue => error
              raise StandardError, (+<<~MSG).squish
                Unable to #{event.event_name} the @#{item.gql_name} directive: #{error.message}
              MSG
            end
          end

          result << item
        end
      end
    end
  end
end

require 'rails/graphql/config'
require 'rails/graphql/errors'
require 'rails/graphql/shortcuts'
require 'rails/graphql/railtie'

ActiveSupport.run_load_hooks(:graphql, Rails::GraphQL)
