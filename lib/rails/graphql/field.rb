# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Field
    #
    # A field has multiple purposes, which is defined by the specific subclass
    # used. They are also, in various ways, similar to arguments, since they
    # tend to have the same structure.
    # array as input.
    #
    # ==== Options
    #
    # * <tt>:owner</tt> - The main object that this field belongs to.
    # * <tt>:null</tt> - Marks if the overall type can be null
    #   (defaults to true).
    # * <tt>:array</tt> - Marks if the type should be wrapped as an array
    #   (defaults to false).
    # * <tt>:nullable</tt> - Marks if the internal values of an array can be null
    #   (defaults to true).
    # * <tt>:full</tt> - Shortcut for +null: false, nullable: false, array: true+
    #   (defaults to false).
    # * <tt>:enabled</tt> - Mark the field as enabled
    #   (defaults to true).
    # * <tt>:disabled</tt> - Works as the opposite of the enabled option
    #   (defaults to false).
    # * <tt>:directives</tt> - The list of directives associated with the value
    #   (defaults to nil).
    # * <tt>:desc</tt> - The description of the argument
    #   (defaults to nil).
    #
    # It also accepts a block for further configurations
    class Field
      extend ActiveSupport::Autoload
      include Helpers::WithDirectives
      include Helpers::WithDescription

      autoload :ScopedConfig

      autoload :AuthorizedField
      autoload :ProxiedField
      autoload :ResolvedField
      autoload :TypedField

      autoload :InputField
      autoload :OutputField
      autoload :MutationField
      autoload :SubscriptionField

      attr_reader :name, :gql_name, :owner

      alias gid_base_class owner
      alias proxied_owner owner
      alias to_sym name

      delegate :namespaces, to: :owner
      delegate :input_type?, :output_type?, :leaf_type?, :proxy?,
        :mutation?, :subscription?, to: :class

      class << self
        # A small shared helper method that allows field information to be
        # proxied
        def proxyable_methods(*list, klass:, allow_nil: false)
          list = list.flatten.compact.map do |method_name|
            ivar = +'@' + method_name.delete_suffix('?')
            accessor = +'field' + (allow_nil ? '&.' : '.') + method_name
            "def #{method_name}; defined?(#{ivar}) ? #{ivar} : #{accessor}; end"
          end

          klass.class_eval(list.join("\n"), __FILE__, __LINE__ + 1)
        end

        # Defines if the current field is valid as an input type
        def input_type?
          false
        end

        # Defines if the current field is valid as an output type
        def output_type?
          false
        end

        # Defines if the current field is considered a leaf output
        def leaf_type?
          false
        end

        # Checks if the the field is a proxy kind of field
        def proxy?
          false
        end

        # Checks if the field is associated with a mutation
        def mutation?
          false
        end

        # Checks if the field is associated with a subscription
        def subscription?
          false
        end
      end

      def initialize(name, owner:, **xargs, &block)
        @owner = owner
        normalize_name(name)

        # TODO: Replace by a proper method to build and set @directives
        directives = GraphQL.directives_to_set(xargs[:directives], source: self)
        @directives = directives unless directives.nil?

        @method_name = xargs[:method_name].to_s.underscore.to_sym \
          unless xargs[:method_name].nil?

        full      = xargs.fetch(:full, false)
        @null     = full ? false : xargs.fetch(:null, true)
        @array    = full ? true  : xargs.fetch(:array, false)
        @nullable = full ? false : xargs.fetch(:nullable, true)
        @gql_name = xargs.fetch(:gql_name, @gql_name)

        self.description = xargs[:desc] || xargs[:description]
        @enabled = xargs.fetch(:enabled, !xargs.fetch(:disabled, false))

        configure(&block) if block.present?
      end

      def initialize_copy(*)
        super

        @owner = nil
      end

      # Apply a controlled set of changes to the field
      def apply_changes(**xargs, &block)
        required_items! unless xargs.fetch(:nullable, true)
        required! unless xargs.fetch(:null, true)
        disable! if xargs.fetch(:disabled, false)
        enable! if xargs.fetch(:enabled, false)

        self.description = xargs[:desc] if xargs.key?(:desc)
        self.description = xargs[:description] if xargs.key?(:description)
        configure(&block) if block.present?
      end

      # Allow extra configurations to be performed using a block
      def configure(&block)
        Field::ScopedConfig.new(self, block.binding.receiver).instance_exec(&block)
        self
      end

      # Return the owner as the single item of the list
      def all_owners
        [owner]
      end

      # Returns the name of the method used to retrieve the information
      def method_name
        if defined?(@method_name)
          @method_name
        elsif from_alternative?
          :resolve
        else
          @name
        end
      end

      # Mark the field as globally enabled
      def enable!
        @enabled = true
      end

      # Mark the field as globally disabled
      def disable!
        @enabled = false
      end

      # Update the null value
      def required!
        @null = false
      end

      # Update the nullable value
      def required_items!
        @nullable = false
      end

      # Checks if the field can be null
      def null?
        !!@null
      end

      # Checks if the field cannot br null
      def required?
        !null?
      end

      # Checks if the field can be an array
      def array?
        !!@array
      end

      # Checks if the field can have null elements in the array
      def nullable?
        !!@nullable
      end

      # Check if tre field is enabled
      def enabled?
        !!@enabled
      end

      # Check if tre field is disabled
      def disabled?
        !enabled?
      end

      # Override to add the kind
      def description(namespace = nil, *)
        super(namespace, :field)
      end

      # Check if the field is an internal one
      def internal?
        name.start_with?('__')
      end

      # This method must be overridden by children classes
      def valid_input?(*)
        enabled?
      end

      # This method must be overridden by children classes
      def valid_output?(*)
        enabled?
      end

      # Transforms the given value to its representation in a JSON string
      def to_json(*)
        raise NotImplementedError, +"#{self.class.name} does not implement to_json"
      end

      # Turn the given value into a JSON string representation
      def as_json(*)
        raise NotImplementedError, +"#{self.class.name} does not implement as_json"
      end

      # Turn a user input of this given type into an ruby object
      def deserialize(*)
        raise NotImplementedError, +"#{self.class.name} does not implement deserialize"
      end

      # Check if the given value is valid using +valid_input?+ or
      # +valid_output?+ depending of the type of the field
      def valid?(value)
        input_type? ? valid_input?(value) : valid_output?(value)
      end

      # Checks if the definition of the field is valid.
      def validate!(*)
        super if defined? super

        raise NameError, (+<<~MSG).squish if gql_name.start_with?('__') && !internal?
          The name "#{gql_name}" is invalid. Only internal fields from the
          spec can have a name starting with "__".
        MSG
      end

      # Create a proxy of the current field
      def to_proxy(*args, **xargs, &block)
        proxy = self.class.allocate
        proxy.extend Field::ProxiedField
        proxy.send(:proxied)
        proxy.send(:initialize, self, *args, **xargs, &block)
        proxy
      end

      # Check if the other field is equivalent
      def =~(other)
        other.is_a?(GraphQL::Field) &&
          other.array? == array? &&
          (other.null? == null? || other.null? && !null?) &&
          (other.nullable? == nullable? || other.nullable? && !nullable?)
      end

      def inspect
        (+<<~INFO).squish << '>'
          #<GraphQL::#{self.class.name.split('::').last}
          #{inspect_owner&.split(+'GraphQL::')&.last&.sub(+'::NestedTypes', '')}
          #{inspect_source}
          #{inspect_enabled}
          #{gql_name}#{inspect_arguments}#{inspect_type}
          #{inspect_default_value}
          #{inspect_directives}
        INFO
      end

      protected

        # Allow the subclasses to define the extra inspection methods
        def respond_to_missing?(method_name, *)
          method_name.start_with?('inspect_') || super
        end

        # Allow the subclasses to define the extra inspection methods
        def method_missing(method_name, *)
          method_name.start_with?('inspect_') ? '' : super
        end

        # Ensures the consistency of the name of the field
        def normalize_name(value)
          return if value.blank?

          @name = value.to_s.underscore.to_sym
          @gql_name = @name.to_s.gsub(/^_+/, '').camelize(:lower)

          if internal?
            @gql_name.prepend('__')
          elsif @name.start_with?('_')
            @gql_name.prepend('_')
          end
        end

        # Check if the field was defined as an alternative class
        def from_alternative?
          proxied_owner.is_a?(Module) && proxied_owner <= Alternative::Query
        end

        # Show the name of the owner of the object for inspection
        def inspect_owner
          owner.is_a?(Module) ? owner.name : owner.class.name
        end

        # Add a disable tag to the inspection if the field is disabled
        def inspect_enabled
          '[disabled]' if disabled?
        end
    end
  end
end
