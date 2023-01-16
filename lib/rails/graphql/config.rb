# frozen_string_literal: true

module Rails
  module GraphQL
    configure do |config|
      # This helps to keep track of when things were cached and registered.
      # Cached objects with mismatching versions needs to be upgraded or simply
      # reloaded. A good way to use this is to set to the commit hash, but
      # beware to stick to 8 characters.
      config.version = nil

      # This will be automatically mapped to +Rails.cache+. Manually setting
      # this property means that the object in it complies with
      # +ActiveSupport::Cache::Store+.
      config.cache = nil

      # If Rails cache is not properly defined, by default it is set to a
      # NullStore, than fallback to this option to get a memory store because
      # cache is extremely important, especially for subscriptions
      config.cache_fallback = -> do
        ::ActiveSupport::Cache::MemoryStore.new(max_prune_time: nil)
      end

      # This is the prefix key of all the cache entries for the GraphQL cached
      # things.
      config.cache_prefix = 'graphql/'

      # The list of nested paths inside of the graphql folder that does not
      # require to be in their own namespace.
      config.paths = %w[queries mutations subscriptions directives fields
        sources enums inputs interfaces objects scalars unions].to_set

      # This exposes the clean path from where a GraphQL request was started.
      config.verbose_logs = true

      # The list of parameters to omit from logger when running a GraphQL
      # request. Those values will be better displayed in the internal runtime
      # logger controller.
      config.omit_parameters = %w[query operationName operation_name variables graphql]

      # This list will actually affect what is displayed in the logs. When it is
      # set to nil, it will copy its value from Rails +filter_parameters+.
      config.filter_parameters = nil

      # A list of ActiveRecord adapters and their specific internal naming used
      # to compound the accessors for direct query serialization.
      config.ar_adapters = {
        'Mysql2'     => { key: :mysql,  path: "#{__dir__}/adapters/mysql_adapter" },
        'PostgreSQL' => { key: :pg,     path: "#{__dir__}/adapters/pg_adapter" },
        'SQLite'     => { key: :sqlite, path: "#{__dir__}/adapters/sqlite_adapter" },
      }

      # For all the input object type defined, auto add the following prefix to
      # their name, so we don't have to define classes like +PointInputInput+.
      config.auto_suffix_input_objects = 'Input'

      # Introspection is enabled by default. Changing this will affect all the
      # schemas off the application and reduce memory usage. This can also be
      # set at per schema.
      config.enable_introspection = true

      # Define the names of the schema/operations types. The single "_" is a
      # suggestion so that in an application that has, most likely, a
      # Subscription type, it does not generate a conflict. Plus, it is easy to
      # spot that it is something internal.
      config.schema_type_names = {
        query: '_Query',
        mutation: '_Mutation',
        subscription: '_Subscription',
      }

      # For performance purposes, this gem implements a
      # {JsonCollector}[rdoc-ref:Rails::GraphQL::Collectors::JsonCollector].
      # If you prefer to use the normal hash to string serialization, you can
      # disable this option.
      config.enable_string_collector = true

      # Set what is de default expected output type of GraphQL requests. String
      # combined with the previous setting has the best performance. On console,
      # it will automatically shift to hash.
      config.default_response_format = :string

      # Specifies if the results of operations should be encoded with
      # +ActiveSupport::JSON#encode+ instead of the default +JSON#generate+.
      # See also https://github.com/rails/rails/blob/master/activesupport/lib/active_support/json/encoding.rb
      config.encode_with_active_support = false

      # Enable the ability of a callback to dynamically inject arguments to the
      # calling method.
      config.callback_inject_arguments = true

      # Enable the ability of a callback to dynamically inject named arguments
      # to the calling method.
      config.callback_inject_named_arguments = true

      # When importing fields into other places, if the given class is
      # incompatible it will display an warning. This can make such warning be
      # silenced.
      config.silence_import_warnings = false

      # Enable the ability to active custom descriptions using i18n
      config.enable_i18n_descriptions = true

      # Specify the scopes for I18n translations
      config.i18n_scopes = [
        'graphql.%{namespace}.%{kind}.%{parent}.%{name}',
        'graphql.%{namespace}.%{kind}.%{name}',
        'graphql.%{namespace}.%{name}',
        'graphql.%{kind}.%{parent}.%{name}',
        'graphql.%{kind}.%{name}',
        'graphql.%{name}'
      ]

      # A list of execution strategies. Each application can add their own by
      # simply append a class name, preferable as string, in this list.
      config.request_strategies = [
        'Rails::GraphQL::Request::Strategy::MultiQueryStrategy',
        'Rails::GraphQL::Request::Strategy::SequencedStrategy',
        # 'Rails::GraphQL::Request::Strategy::CachedStrategy',
      ]

      # A list of all possible rails-graphql-compatible sources.
      config.sources = [
        'Rails::GraphQL::Source::ActiveRecordSource',
      ]

      # A list of all available subscription providers which bases on
      # Rails::GraphQL::SubscriptionProvider::Base
      config.subscription_providers = [
        'Rails::GraphQL::Subscription::Provider::ActionCable',
      ]

      # The default subscription provider for all the schemas
      config.default_subscription_provider = config.subscription_providers.first

      # The default value for fields about their ability of being broadcasted
      config.default_subscription_broadcastable = nil

      # A list of known dependencies that can be requested and included in any
      # schema. This is the best place for other gems to add their own
      # dependencies and allow users to pick them.
      config.known_dependencies = {
        scalar: {
          any:       "#{__dir__}/type/scalar/any_scalar",
          bigint:    "#{__dir__}/type/scalar/bigint_scalar",
          binary:    "#{__dir__}/type/scalar/binary_scalar",
          date_time: "#{__dir__}/type/scalar/date_time_scalar",
          date:      "#{__dir__}/type/scalar/date_scalar",
          decimal:   "#{__dir__}/type/scalar/decimal_scalar",
          time:      "#{__dir__}/type/scalar/time_scalar",
          json:      "#{__dir__}/type/scalar/json_scalar",
        },
        directive: {
          # cached:    "#{__dir__}/directive/cached_directive",
        },
      }

      # The method that should be used to parse literal input values when they
      # are provided as hash. +JSON.parse+ only supports keys wrapped in quotes,
      # to support keys without quotes, you can use +Psych.method(:safe_load)+,
      # which behaves closer to YAML, but the received value is ensure to be
      # wrapped in "{}". If that produces unexpected results, you can assign a
      # proc and then parse the value in any other way, like
      # +->(value) { anything }+
      config.literal_input_parser = JSON.method(:parse)

      # TODO: To be implemented
      # allow_query_serialization
    end

    # This is the logger for all the operations for GraphQL
    def self.logger
      config.logger ||= ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
    end
  end
end
