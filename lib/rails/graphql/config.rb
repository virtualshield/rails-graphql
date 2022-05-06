# frozen_string_literal: true

module Rails
  module GraphQL
    configure do |config|
      # This helps to keep track of when things were cached and registered.
      # Cached objects with mismatching versions needs to be upgraded or simply
      # reloaded. A good way to use this is to set to the commit hash, but
      # beware to stick to 8 characters.
      config.version = nil

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
        'Mysql2'     => :mysql,
        'PostgreSQL' => :pg,
        'SQLite'     => :sqlite,
      }

      # For all the input object type defined, auto add the following prefix to
      # their name, so we don't have to define classes like +PointInputInput+.
      config.auto_suffix_input_objects = 'Input'

      # For performance purposes, this gem implements a
      # {JsonCollector}[rdoc-ref:Rails::GraphQL::Collectors::JsonCollector].
      # If you prefer to use the normal hash to string serialization, you can
      # disable this option.
      config.enable_string_collector = true

      # Specifies if the results of operations should be encoded with
      # +ActiveSupport::JSON#encode+ instead of the default +JSON#generate+.
      # See also https://github.com/rails/rails/blob/master/activesupport/lib/active_support/json/encoding.rb
      config.encode_with_active_support = false

      # Enable the ability of a callback to dynamically inject argumnets to the
      # calling method.
      config.callback_inject_arguments = true

      # Enable the ability of a callback to dynamically inject named argumnets
      # to the calling method.
      config.callback_inject_named_arguments = true

      # A list of execution strategies. Each application can add their own by
      # simply append a class name, preferable as string, in this list.
      config.request_strategies = [
        'Rails::GraphQL::Request::Strategy::MultiQueryStrategy',
        'Rails::GraphQL::Request::Strategy::SequencedStrategy',
      ]

      # TODO: To be implemented
      # enable_i18n_descriptions
      # enable_auto_descriptions
      # allow_query_serialization
      # source_generate_dependencies
    end

    # This is the logger for all the operations for GraphQL
    def self.logger
      config.logger ||= ActiveSupport::TaggedLogging.new(
        ActiveSupport::Logger.new(STDOUT),
      )
    end
  end
end
