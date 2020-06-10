# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Core
      ##
      # :singleton-method:
      # Accepts a logger conforming to the interface of Log4r which is then
      # passed on to any graphql operation which can be retrieved on both a class
      # and instance level by calling +logger+.
      mattr_accessor :logger, instance_writer: false

      ##
      # :singleton-method:
      # A list of ActiveRecord adapters and their specific internal naming used
      # to compound the accessors for direct query serialization
      mattr_accessor :ar_adapters, instance_writer: false, default: {
        'Mysql2'     => :mysql,
        'PostgreSQL' => :pg,
        'SQLite'     => :sqlite,
      }

      ##
      # :singleton-method:
      # Initialize the class responsible for registering and keeping all the
      # types and objects correctly registered.
      mattr_accessor :type_map, instance_writer: false, default: GraphQL::TypeMap.new

      ##
      # :singleton-method:
      # For all the input object type defined, auto add the following prefix to
      # their name, so we don't have to define classes like +PointInputInput+.
      mattr_accessor :auto_suffix_input_objects, instance_writer: false, default: 'Input'

      ##
      # :singleton-method:
      # Set this to true in order to enable the descriptions of anything be
      # defined on locale files form I18n, which also provides support for
      # language translations.
      mattr_accessor :enable_i18n_descriptions, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Set this to true in order to enable the automatic generation of
      # description for fields that the description is missing. This has the
      # lowest priority.
      mattr_accessor :enable_auto_descriptions, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Marks if the JSON serialization of an ActiveRecord object can happen
      # during the query, which has better performance. It will only be used
      # whenever is possible.
      mattr_accessor :allow_query_serialization, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Specifies if the results of operations should be encoded with
      # +ActiveSupport::JSON#encode+ instead of the default +JSON#generate+.
      # See also https://github.com/rails/rails/blob/master/activesupport/lib/active_support/json/encoding.rb
      mattr_accessor :encode_with_active_support, instance_writer: false, default: false

      ##
      # Set specific configurations for GraphiQL portion of the gem. You can
      # disable it by passing a false value.
      #
      # +config+ Either +false+ to disable or a +Hash+ with further settings
      def self.graphiql=(config)
        return unless config.present?

        GraphiQL.enabled = true
        config.try(:each) { |k, v| GraphiQL.send "#{k}=", v }
      end
    end
  end
end
