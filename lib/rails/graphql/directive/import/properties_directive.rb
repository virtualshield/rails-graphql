# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Import Properties Directive
    #
    # Provide a set of properties to be assigned to a field
    class Directive::PropertiesDirective < Directive
      self.hidden = true

      DESCRIPTIONS = {
        max_repetition: 'Limits array values output',
        max_complexity: 'Limits the underlying complexity',
        max_depth: 'Limits the underlying depth',
        complexity: 'The unit complexity of the field',
        needs: 'External properties needed for fulfilling this field',
      }

      placed_on :field_definition, :input_field_definition

      desc 'A list of properties that further defines fields'

      on(:attach) { |event| event.source.properties = args }

      class << self
        # Hook into register process to make sure the directive is properly
        # configured
        def register!
          configure!
          super
        end

        # Check if this directive has been configured
        def configured?
          dynamic? || arguments.any?
        end

        # Properly configure the directive
        def configure!
          return if configured?

          # Load the config and check if should be set to dynamic
          config = Rails::GraphQL.config.field_properties
          return self.dynamic = true if config.nil?

          # Create the arguments based on the config
          config.each { |name, type| argument(name, type, desc: DESCRIPTIONS[name]) }
        end
      end

      def initialize(*)
        self.class.configure!
        super
      end
    end
  end
end
