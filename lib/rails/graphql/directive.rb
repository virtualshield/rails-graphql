# frozen_string_literal: true

module Rails
  module GraphQL
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
      extend Helpers::WithEvents
      extend Helpers::WithCallbacks
      extend Helpers::WithArguments
      extend Helpers::WithGlobalID
      extend Helpers::Registerable

      EXECUTION_LOCATIONS  = %i[
        query mutation subscription field fragment_definition fragment_spread inline_fragment
      ].to_set.freeze

      DEFINITION_LOCATIONS = %i[
        schema scalar object field_definition argument_definition interface union
        enum enum_value input_object input_field_definition
      ].to_set.freeze

      VALID_LOCATIONS = (EXECUTION_LOCATIONS + DEFINITION_LOCATIONS).freeze

      class << self
        def kind
          :directive
        end

        # Ensure to return the directive class
        def base_type
          GraphQL::Directive
        end

        alias gid_base_class base_type

        # Return the name of the object as a GraphQL name, ensure to use the
        # first letter as lower case when being auto generated
        def gql_name
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

        # A helper method that allows directives to be initialized while
        # correctly parsing the arguments
        def build(**xargs)
          xargs = xargs.stringify_keys
          result = all_arguments&.each&.each_with_object({}) do |(name, argument), hash|
            hash[name] = argument.deserialize(xargs[argument.gql_name] || xargs[name.to_s])
          end

          new(**result)
        end

        # Return the directive, instantiate if it has params
        def find_by_gid(gid)
          options = { namespaces: gid.namespace, base_class: :Directive }
          klass = GraphQL.type_map.fetch!(gid.name, **options)
          gid.instantiate? ? klass.build(**gid.params) : klass
        end

        def inspect
          return super if eql?(GraphQL::Directive)

          repeatable = ' [repeatable]' if repeatable?
          args = all_arguments&.each_value&.map(&:inspect)
          args = args.force if args.respond_to?(:force)
          args = args.presence && "(#{args.join(', ')})"
          +"#<GraphQL::Directive @#{gql_name}#{repeatable}#{args}>"
        end

        private

          # Provide a nice way to use a directive without calling
          # +Directive.new+, like the +DeprecatedDirective+ can be initialized
          # using +GraphQL::DeprecatedDirective(*args)+
          def inherited(subclass)
            subclass.abstract = false
            super if defined? super

            return if subclass.anonymous?
            method_name = subclass.name.demodulize
            subclass.module_parent.define_singleton_method(method_name) do |*args, &block|
              subclass.new(*args, &block)
            end
          end

          # A helper method that allows the +on+ and +for+ event filters to be
          # used with things from both the TypeMap and the GraphQL shortcut
          # classes
          def sanitize_objects(setting)
            GraphQL.enumerate(setting).map do |item|
              next item unless item.is_a?(String) || item.is_a?(Symbol)
              GraphQL.type_map.fetch(item, namespaces: namespaces) ||
                ::GraphQL.const_get(item)
            end
          end

          # Check if the given list the locations are valid
          def validate_locations!(list)
            invalid = list.flatten.lazy.reject do |item|
              item = item.to_s.underscore.to_sym unless item.is_a?(Symbol)
              VALID_LOCATIONS.include?(item)
            end

            raise ArgumentError, (+<<~MSG).squish if invalid.any?
              Invalid locations for @#{gql_name}: #{invalid.force.to_sentence}.
            MSG
          end
      end

      # Marks if the directive may be used repeatedly at a single location
      class_attribute :repeatable, instance_accessor: false, default: false

      self.abstract = true

      autoload :DeprecatedDirective
      autoload :IncludeDirective
      autoload :SkipDirective
      autoload :SpecifiedByDirective

      autoload :CachedDirective

      delegate :locations, :gql_name, :gid_base_class, :repeatable?, to: :class

      # TODO: This filters are a bit confusing now, but `for` is working for @deprecated
      event_filter(:for) do |options, event|
        sanitize_objects(options).any?(&event.source.method(:of_type?))
      end

      event_filter(:on) do |options, event|
        event.respond_to?(:on?) && sanitize_objects(options).any?(&event.method(:on?))
      end

      event_filter(:during) do |options, event|
        event.key?(:phase) && GraphQL.enumerate(options).include?(event[:phase])
      end

      attr_reader :args, :event

      def initialize(args = nil, **xargs)
        @args = args || OpenStruct.new(xargs.transform_keys { |key| key.to_s.underscore })
        @args.freeze
      end

      # Once the directive is correctly prepared, we need to assign the owner
      def assign_owner!(owner)
        raise ArgumentError, (+<<~MSG).squish if defined?(@owner)
          Owner already assigned for @#{gql_name} directive.
        MSG

        @owner = owner
      end

      # Correctly turn all the arguments into their +as_json+ version and return
      # a hash of them
      def args_as_json
        all_arguments&.each&.with_object({}) do |(name, argument), hash|
          hash[argument.gql_name] = argument.as_json(@args[name])
        end
      end

      # Correctly turn all the arguments into their +to_json+ version and return
      # a hash of them
      def args_to_json
        all_arguments&.each&.with_object({}) do |(name, argument), hash|
          hash[argument.gql_name] = argument.to_json(@args[name])
        end
      end

      # When fetching all the events, embed the actual instance as the context
      # of the callback
      def all_events
        return unless self.class.events?

        @all_events ||= self.class.all_events.transform_values do |events|
          events.map { |item| Callback.set_context(item, self) }
        end
      end

      # Checks if all the arguments provided to the directive instance are valid
      def validate!(*)
        raise ArgumentError, (+<<~MSG).squish unless defined?(@owner)
          The @#{gql_name} directive is unbounded.
        MSG

        invalid = all_arguments&.reject { |name, arg| arg.valid?(@args[name]) }
        return if invalid.blank?

        invalid = invalid.each_key.map { |name| (+<<~MSG).squish }
          invalid value "#{@args[name].inspect}" for #{name} argument
        MSG

        raise ArgumentError, (+<<~MSG).squish
          Invalid usage of @#{gql_name} directive: #{invalid.to_sentence}.
        MSG
      end

      # This allows combining directives
      def +(other)
        [self, other].flatten
      end

      alias_method :&, :+

      def inspect
        args = all_arguments&.filter_map do |name, arg|
          +"#{arg.gql_name}: #{@args[name].inspect}" unless @args[name].nil?
        end

        args = args.presence && +"(#{args.join(', ')})"
        repeatable = ' [repeatable]' if repeatable?
        unbound = ' # unbound' unless defined?(@owner)
        +"@#{gql_name}#{repeatable}#{args}#{unbound}"
      end

      %i[to_global_id to_gid to_gid_param].each do |method_name|
        define_method(method_name) do
          # TODO: The option is kind of broken, because they should always be a Hash
          self.class.public_send(method_name, args_as_json&.compact || '')
        end
      end

    end
  end
end
