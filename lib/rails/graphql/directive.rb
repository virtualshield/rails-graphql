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
    # Directives works as event listener and trigger, which means that some
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
      extend Helpers::InheritedCollection
      extend Helpers::WithArguments
      extend Helpers::Registerable

      eager_autoload do
        autoload :SkipDirective
        autoload :IncludeDirective
        autoload :DeprecatedDirective
      end

      VALID_LOCATIONS = Rails::GraphQL::Type::Enum::DirectiveLocationEnum
        .values.to_a.map { |value| value.downcase.to_sym }.freeze

      # The list of events listeners in order to process a directive
      inherited_collection :events, default: (Hash.new { |h, k| h[k] = [] })

      class << self
        def gql_name # :nodoc:
          return @gql_name if defined?(@gql_name)
          @gql_name = super.camelize(:lower)
        end

        # Get the list of locations of a the directive
        def locations
          @locations ||= Set.new
        end

        # A secure way to specify the locations of a the directive
        def placed_on(*list)
          validate_locations!(list)
          @locations = (superclass.try(:locations)&.dup || Set.new) \
            unless defined?(@locations)

          @locations.merge(list)
        end

        # This method overrides the locations of a the directive
        def placed_on!(*list)
          validate_locations!(list)
          @locations = list.to_set
        end

        # Add an event listener to the directive
        def on(event_name, **options, &block)
          method_name = options[:prepend] ? :unshift : :push
          events[event_name].send(method_name, block)
        end

        def eager_load! # :nodoc:
          super

          TypeMap.loaded! :Directive
        end

        def inspect # :nodoc:
          args = arguments.each_value.map(&:inspect)
          args = args.presence && "(#{args.join(', ')})"
          "#<GraphQL::Directive @#{gql_name}#{args}>"
        end

        private

          # Check if the given list the locations are valid
          def validate_locations!(list)
            list.flatten!
            list.map! { |item| item.to_s.underscore.to_sym }

            invalid = list - VALID_LOCATIONS
            raise ArgumentError, <<~MSG.squish unless invalid.empty?
              Invalid locations for @#{gql_name}: #{invalid.to_sentence}
            MSG
          end

          # Provide a nice way to use a directive without calling +Directive.new+
          def inherited(subclass)
            super if defined? super

            method_name = subclass.name.demodulize
            subclass.module_parent.define_singleton_method(method_name) do |*args, &block|
              subclass.new(*args, &block)
            end
          end

          # Allows checking value existence
          def respond_to_missing?(method_name, include_private = false)
            const_defined?(method_name) || autoload?(method_name) || super
          end

          # Allow fast creation of values
          def method_missing(method_name, *args, &block)
            const_get(method_name)&.new(*args, &block) || super
          rescue ::NameError
            super
          end
      end

      attr_reader :args

      delegate :locations, :gql_name, to: :class
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
        catch(:done) { all_events[event_name].each { |block| instance_exec(&block) } }
      ensure
        @scope = nil
      end

      # Checks if all the arguments provided to the directive instance are valid
      def validate!(*)
        invalid = arguments.reject { |name, arg| arg.valid?(@args[name]) }
        return if invalid.empty?

        invalid.map! { |name, arg| <<~MSG }
          Invalid value "#{@args[name].inspect}" for #{name} argument.
        MSG

        raise ArgumentError, <<~MSG.squish
          Invalid usage of @#{gql_name} directive: #{invalid.to_sentence}
        MSG

        nil # No exception already means valid
      end
    end
  end
end

