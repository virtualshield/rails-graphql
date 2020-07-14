# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Proxy Field
    #
    # Proxy fields are a soft way to copy a real field. The good part is that if
    # the field changes for any reason all its copies will change as well.
    #
    # The owner of a proxy field is different from the owner of the actual field
    # but that doesn't affect the field operations.
    #
    # Proxy field also supports aliases, which helps implementing independent
    # fields and then providing them as proxy to other objects
    #
    # ==== Options
    #
    # * <tt>:as</tt> - The actual name to be used on the field while assigning
    #   the proxy (defaults to nil).
    # * <tt>:method_name</tt> - Provides a diferent +method_name+ from where to
    #   extract the data (defaults to nil).
    class ProxyField < ActiveSupport::ProxyObject
      include Field::Core
      include Field::ResolvedField
      include Field::TypedOutputField

      alias self_dynamic_resolver? dynamic_resolver?

      delegate :type, :group, :array?, :nullable?, :internal?, :arguments, :directives,
        to: :field

      redefine_singleton_method(:output_type?) { true }

      def initialize(field, owner, as: nil, method_name: nil)
        @field = field
        @owner = owner

        if as.present?
          @name = as.to_s.underscore.to_sym

          @gql_name = @name.to_s.camelize(:lower)
          @gql_name = "__#{@gql_name.camelize(:lower)}" if internal?
        end

        @method_name = method_name unless method_name.nil?
      end

      %i[name gql_name method_name null?].each do |name|
        ivar = name.to_s.delete_suffix('?')
        instance_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{name}
            defined?(@#{ivar}) ? @#{ivar} : field.#{name}
          end
        RUBY
      end

      def dynamic_resolver? # :nodoc:
        super || field.dynamic_resolver?
      end

      def inspect(extra = '')
        <<~INSPECT.squish + '>'
          #<GraphQL::ProxyField
          @owner="#{owner.name}"
          @source="#{field.owner.name}[:#{field.name}]"
          #{gql_name}#{inspect_arguments}:#{extra}#{inspect_directives}
        INSPECT
      end

      protected

        def run_resolver(context)
          self_dynamic_resolver? ? super : field.run(:resolver, context)
        end

        def run_hooks(hook, context)
          super
          field.run(hook, context)
        end
    end
  end
end
