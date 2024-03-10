# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Field Properties
    #
    # This module is responsible for managing field properties to any kind of
    # field. It set up the basic structure and properly manages the information
    # for proxied fields.
    module Field::Properties
      # The base class for all properties, which can be an OpenStruct or a
      # strict Struct given the `field_properties` setting
      def self.structure
        @@structure ||= begin
          config = Rails::GraphQL.config.field_properties
          config.present? ? Struct.new(*config.keys) : OpenStruct
        end
      end

      def initialize(*args, properties: nil, **xargs, &block)
        self.properties = properties unless properties.nil?
        super(*args, **xargs, &block)
      end

      # Check if the field has any properties defined
      def properties?
        defined?(@properties)
      end

      # Get access to the properties of the field
      def properties
        @properties ||= Field::Properties.structure.new
      end

      # Allow assigning several properties at once
      def properties=(value)
        raise ::ArgumentError, (+<<~MSG).squish unless value.is_a?(Hash)
          The properties must be a Hash, but received #{value.class}.
        MSG

        value.each_with_object(properties) do |(key, value), hash|
          hash[key] = value
        end
      end

      # Freeze the properties as soon as the field is validated
      def validate!(*)
        @properties.freeze if properties?
        super if defined? super
      end

      protected

        def proxied
          super if defined? super
          @properties = field.properties.dup if field.properties?
        end
    end

    Field::ScopedConfig.delegate :properties, to: :field
  end
end
