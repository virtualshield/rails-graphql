# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Directive
    #
    # This is the base object for directives definition.
    # See: http://spec.graphql.org/June2018/#DirectiveDefinition
    #
    # Whenever you want to use a directive, you can use the ClassName(...)
    # shortcut (which is the same as ClassName.new(...)).
    #
    # Directives works as event listner and trigger, which means that some
    # actions will trigger directives events, and the directive can listen to
    # these events and perform an action
    #
    # ==== Examples
    #
    #   argument :test, :boolean, directives: FlagDirective()
    #
    #   # On defining an enum value
    #   add :old_value, directives: DeprecatedDirective(reason: 'not used anymore')
    class Directive
      extend ActiveSupport::Autoload
      extend GraphQL::NamedDefinition
      extend Helpers::WithArguments

      autoload :SkipDirective
      autoload :IncludeDirective
      autoload :DeprecatedDirective

      VALID_LOCATIONS = Rails::GraphQL::Type::Enum::DirectiveLocationEnum
        .values.to_a.map { |value| value.downcase.to_sym }.freeze

      # Marks if the object is one of those defined on the spec, which marks the
      # direvtive as a standard one
      class_attribute :spec_object, instance_writer: false, default: false

      # The given description of the directive
      class_attribute :description, instance_writer: false

      # The list of locations where the given directive can be used
      inherited_collection :locations, default: Set.new

      # The list of events listeners in order to process a directive
      inherited_collection :events, default: (Hash.new { |h, k| h[k] = [] })

      class << self
        # Provide a nice way to use a directive without calling +Directive.new+
        def inherited(subclass)
          method_name = subclass.name.demodulize
          subclass.module_parent.define_singleton_method(method_name) do |*args, &block|
            subclass.new(*args, &block)
          end
        end

        def gql_name # :nodoc:
          super.camelize(:lower)
        end

        # An alias for +description = value+ that can be used as method
        def desc(value)
          self.description = value.squish
        end

        # A secure way to specify the locations of a given directive
        def placed_on(*values)
          values = values.flatten.map(&:to_sym)
          invalid = values - VALID_LOCATIONS
          return self.locations.merge(values) if invalid.empty?

          # TODO: Add a correct exception here
          raise "Invalid locations for @#{gql_name}: #{invalid.to_sentence}"
        end

        # Add an event listener to the directive
        def on(event_name, unshift: false, &block)
          method_name = unshift ? :unshift : :push
          events[event_name].send(method_name, block)
        end

        private

          # Allows checking value existance
          def respond_to_missing?(method_name, include_private = false)
            const_defined?(method_name) || autoload?(method_name) || super
          end

          # Allow fast creation of values
          def method_missing(method_name, *args, &block)
            const_get(method_name)&.new(*args, &block) || super
          rescue NameError
            super
          end
      end

      attr_reader :args

      delegate_missing_to :@scope

      def initialize(**xargs)
        xargs = xargs.transform_keys { |key| key.to_s.underscore }
        @args = OpenStruct.new(xargs)
        validate!
      end

      # Triggers a specific event under the given scope. You can use
      # +throw :done, optional_result+ as a way to early return from the events
      def trigger(event_name, scope)
        @scope = scope
        catch(:done) { all_events[event_name].each { |block| block.call } }
      ensure
        @scope = nil
      end

      # Checks if all the arguments provided to the directive instance are valid
      def validate!
        invalid = all_arguments.reject { |name, arg| arg.valid?(@args[name]) }
        return if invalid.empty?

        invalid.map! { |name, arg| <<~MSG }
          Invalid value "#{@args[name].inspect}" for #{name} argument.
        MSG

        # TODO: Create a exception class and send the invalid as details
        raise "Invalid usage of @#{gql_name} directive: #{invalid.to_sentence}"
      end
    end
  end
end

