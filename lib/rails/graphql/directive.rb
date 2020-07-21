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

      eager_autoload do
        # TODO: Remove
        autoload :AlwaysVaderDirective

        autoload :SkipDirective
        autoload :IncludeDirective
        autoload :DeprecatedDirective
      end

      VALID_LOCATIONS = Rails::GraphQL::Type::Enum::DirectiveLocationEnum
        .values.to_a.map { |value| value.downcase.to_sym }.freeze

      EXECUTION_LOCATIONS  = VALID_LOCATIONS[0..6].freeze
      DEFINITION_LOCATIONS = VALID_LOCATIONS[7..17].freeze

      attr_reader :args

      delegate :locations, :gql_name, to: :class

      event_types %i[query mutation subscription request attach requested prepare finalize]

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
            subclass.module_parent.define_singleton_method(method_name) do |*args, &block|
              subclass.new(*args, &block)
            end
          end

          # Allows checking value existence
          def respond_to_missing?(method_name, include_private = false)
            (const_defined?(method_name) rescue nil) || autoload?(method_name) || super
          end

          # Allow fast creation of values
          def method_missing(method_name, *args, &block)
            const_get(method_name)&.new(*args, &block) || super
          rescue ::NameError
            super
          end
      end

      def initialize(args = nil, **xargs)
        @args = args || OpenStruct.new(xargs.transform_keys { |key| key.to_s.underscore })
        @args.freeze
        validate!
      end

      # Checks if all the arguments provided to the directive instance are valid
      def validate!(*)
        invalid = arguments.reject { |name, arg| arg.valid?(@args[name]) }
        return if invalid.empty?

        invalid = invalid.map { |name, arg| <<~MSG }
          Invalid value "#{@args[name].inspect}" for #{name} argument.
        MSG

        raise ArgumentError, <<~MSG.squish
          Invalid usage of @#{gql_name} directive: #{invalid.to_sentence}.
        MSG

        nil # No exception already means valid
      end

      def inspect # :nodoc:
        args = arguments.map do |name, arg|
          "#{arg.gql_name}: #{@args[name].inspect}" unless @args[name].nil?
        end.compact

        args = args.presence && "(#{args.join(', ')})"
        "@#{gql_name}#{args}"
      end
    end
  end
end
