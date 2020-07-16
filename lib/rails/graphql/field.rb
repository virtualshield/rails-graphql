# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Field
    #
    # A field has multiple purposes, which is defined by the specific subclass
    # used. They are also, in various ways, similar to arguments, since they
    # tend to have the same structure.
    # array as input.
    #
    # ==== Options
    #
    # * <tt>:owner</tt> - The may object that this field belongs to.
    # * <tt>:null</tt> - Marks if the overall type can be null
    #   (defaults to true).
    # * <tt>:array</tt> - Marks if the type should be wrapped as an array
    #   (defaults to false).
    # * <tt>:nullable</tt> - Marks if the internal values of an array can be null
    #   (defaults to true).
    # * <tt>:full</tt> - Shortcut for +null: false, nullable: false, array: true+
    #   (defaults to false).
    # * <tt>:method_name</tt> - The name of the method used to fetch the field data
    #   (defaults to nil).
    # * <tt>:directives</tt> - The list of directives associated with the value
    #   (defaults to nil).
    # * <tt>:desc</tt> - The description of the argument
    #   (defaults to nil).
    #
    # It also accepts a block for further configurations
    class Field
      require_relative 'field/scoped_config'
      require_relative 'field/core'

      require_relative 'field/resolved_field'
      require_relative 'field/typed_field'
      require_relative 'field/typed_output_field'

      include Helpers::WithDirectives
      include Field::Core

      require_relative 'field/input_field'
      require_relative 'field/output_field'

      def initialize(name, *args, owner: , **xargs, &block)
        @owner = owner
        normalize_name(name)

        @directives = GraphQL.directives_to_set(xargs[:directives], source: self)
        @method_name = xargs[:method_name].to_s.underscore.to_sym \
          unless xargs[:method_name].nil?

        full      = xargs.fetch(:full, false)
        @null     = full ? false : xargs.fetch(:null, true)
        @array    = full ? true  : xargs.fetch(:array, false)
        @nullable = full ? false : xargs.fetch(:nullable, true)

        @desc = xargs[:desc]&.strip_heredoc&.chomp
        @enabled = xargs.fetch(:enabled, !xargs.fetch(:disabled, false))

        configure(&block) if block.present?
        directives.freeze
        arguments.freeze
      end

      def initialize_copy(*)
        super

        @owner = nil
      end

      def inspect(extra = '') # :nodoc:
        <<~INSPECT.squish + '>'
          #<GraphQL::Field @owner="#{owner.name}"
          #{gql_name}#{inspect_arguments}:#{extra}#{inspect_directives}
        INSPECT
      end
    end
  end
end
