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
      extend Helpers::WithEvents
      extend Helpers::WithCallbacks
      extend Helpers::WithArguments
      extend Helpers::Registerable

      VALID_LOCATIONS = Rails::GraphQL::Type::Enum::DirectiveLocationEnum
        .values.to_a.map { |value| value.downcase.to_sym }.freeze

      EXECUTION_LOCATIONS  = VALID_LOCATIONS[0..6].freeze
      DEFINITION_LOCATIONS = VALID_LOCATIONS[7..17].freeze

      self.abstract = true

      class << self
        def kind # :nodoc
          :directive
        end

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

        def eager_load! # :nodoc:
          super

          TypeMap.loaded! :Directive
        end

        def inspect # :nodoc:
          return "#<GraphQL::Directive>" if self.eql?(GraphQL::Directive)

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
              Invalid locations for @#{gql_name}: #{invalid.to_sentence}.
            MSG
          end

          # Provide a nice way to use a directive without calling
          # +Directive.new+, like the +DeprecatedDirective+ can be initialized
          # using +GraphQL::DeprecatedDirective(*args)+
          def inherited(subclass)
            super if defined? super

            method_name = subclass.name.demodulize

            subclass.abstract = false
            subclass.module_parent.define_singleton_method(method_name) do |*args, &block|
              subclass.new(*args, &block)
            end
          end

          # Allows checking value existence
          def respond_to_missing?(method_name, *)
            (const_defined?(method_name) rescue nil) || autoload?(method_name) || super
          end

          # Allow fast creation of values
          def method_missing(method_name, *args, **xargs, &block)
            const_get(method_name)&.new(*args, **xargs, &block) || super
          rescue ::NameError
            super
          end
      end

      eager_autoload do
        autoload :SkipDirective
        autoload :IncludeDirective
        autoload :DeprecatedDirective
      end

      delegate :locations, :gql_name, :all_listeners, to: :class

      array_sanitizer = ->(setting) do
        Array.wrap(setting)
      end

      object_sanitizer = ->(setting) do
        Array.wrap(setting).map! do |item|
          next item unless item.is_a?(String) || item.is_a?(Symbol)
          GraphQL.type_map.fetch(item, namespaces: namespaces) ||
            ::GraphQL.const_get(item)
        end
      end

      event_filter(:for, object_sanitizer) do |options, event|
        options.any?(&event.source.method(:of_type?))
      end

      event_filter(:on, object_sanitizer) do |options, event|
        event.respond_to?(:on?) && options.any?(&event.method(:on?))
      end

      event_filter(:during, array_sanitizer) do |options, event|
        event.key?(:phase) && options.include?(event[:phase])
      end

      attr_reader :args

      def initialize(args = nil, **xargs)
        @args = args || OpenStruct.new(xargs.transform_keys { |key| key.to_s.underscore })
        @args.freeze

        validate! if args.nil?
      end

      # Once the directive is correctly prepared, we need to assign the owner
      def assing_owner!(owner)
        raise ArgumentError, <<~MSG.squish if defined?(@owner)
          Owner already assigned for @#{gql_name} directive.
        MSG

        @owner = owner
      end

      # When fetching all the events, embed the actual instance as the context
      # of the callback
      def all_events
        self.class.all_events.transform_values do |events|
          events.map { |item| Callback.set_context(item, self) }
        end
      end

      # Checks if all the arguments provided to the directive instance are valid
      def validate!(*)
        invalid = all_arguments.reject { |name, arg| arg.valid?(@args[name]) }
        return if invalid.empty?

        invalid = invalid.map { |name, arg| <<~MSG }
          Invalid value "#{@args[name].inspect}" for #{name} argument.
        MSG

        raise ArgumentError, <<~MSG.squish
          Invalid usage of @#{gql_name} directive: #{invalid.to_sentence}.
        MSG
      end

      def inspect # :nodoc:
        args = all_arguments.map do |name, arg|
          "#{arg.gql_name}: #{@args[name].inspect}" unless @args[name].nil?
        end.compact

        args = args.presence && "(#{args.join(', ')})"
        "@#{gql_name}#{args}"
      end
    end
  end
end
