# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Association Field
    #
    # This works similarl to a proxy field, the difference is that it allows the
    # field to be dynamically enabled when the provided associated object is
    # present on the type map. Wheneve the field is actually needed, it will
    # trigger a process to check if the associated object was mapped to the type
    # map and then perform any other needed action
    class Field::AssociationField
      include Helpers::WithDirectives
      include Helpers::WithArguments

      include Field::Core
      include Field::ProxiedField
      include Field::ResolvedField

      overrideable_methods %w[gql_name method_name resolver description null? array? nullable?]

      def initialize(object, field_name = nil, owner: , **xargs, &block)
        @owner = owner
        @object = object
        @field_name = field_name

        xargs[:as] ||= field_name if field_name.present? && !field_name.respond_to?(:call)

        apply_changes(**xargs, &block)
        register_callback(**xargs)
      end

      # Allow chaging smoe other things related to the field
      def apply_changes(**xargs, &block)
        full      = xargs.fetch(:full, false)
        @null     = full ? false : xargs[:null]     if full || xargs.key?(:null)
        @array    = full ? true  : xargs[:array]    if full || xargs.key?(:array)
        @nullable = full ? false : xargs[:nullable] if full || xargs.key?(:nullable)
        super
      end

      # Add a automagically renamed field name, this works great on hash keys
      # since the instance will be different and once the name is loaded
      def name
        return @name if defined?(@name)
        return field.name if activated?
        @delegated_name ||= Helpers::AttributeDelegator.new(self, :name)
      end

      # Only return the owner if the field is activated
      def proxied_owner
        super if activated?
      end

      # The field is only activated when the field is set
      def activated?
        defined?(@field)
      end

      # Check if tre field is enabled
      def enabled?
        activated? && (defined?(@enabled) ? @enabled : field.enabled?)
      end

      def inspect # :nodoc:
        object_name = @object.is_a?(Module) ? @object.name : @object.class.name
        field_name = begin
          if @field_name.respond_to?(:call)
            "(#{@field_name.join(':')})"
          elsif @field_name.present?
            "[#{@field_name.inspect}]"
          end
        end

        extra = (field.send(:inspect_type) rescue nil) if activated?
        args = send(:inspect_arguments) rescue nil

        <<~INSPECT.squish + '>'
          #<GraphQL::Field::AssociationField
          @owner="#{owner.name}"
          #{%{@object=#{object_name}#{field_name}} unless activated?}
          #{%{@source=#{proxied_owner.name}[#{field.name}]} if activated?}
          #{'[pending]' unless activated?}
          #{'[disabled]' if activated? && disabled?}
          #{gql_name}#{args}#{extra}#{inspect_directives}
        INSPECT
      end

      protected

        # Only perform the checking if the field is activated
        def interface_proxy?
          super if activated?
        end

      private

        # Register a callback into the type map in order to wait for the
        # activation of the object
        def register_callback(**xargs)
          group = xargs[:group]
          Core.type_map.after_register(@object, namespaces: namespaces) do |result|
            field = begin
              if @field_name.respond_to?(:call)
                @field_name.call(result)
              elsif @field_name.nil?
                result
              elsif result.respond_to?(@field_name)
                result.public_send(@field_name)
              else
                result[@field_name]
              end
            end

            validate_assignment!(field, group) { @field = field } if field
          end
        end

        # After the field is discovered, check if the assign is valid
        def validate_assignment!(field, group)
          return invalid_assignment!(<<~MSG) unless field.is_a?(GraphQL::Field::Core)
            An association field for #{owner.gql_name} was resolved to
            #{(field.is_a?(Module) ? field.name : field.class.name).inspect},
            which is not a valid field. This field was not activated.
          MSG

          return yield if defined?(@name)

          present = group.nil? ? owner.has_field?(group, field.name) : owner.field?(field.name)
          return yield unless present

          invalid_assignment!(<<~MSG)
            An association field for #{owner.gql_name} was resolved to
            #{field.owner.gql_name}[:#{field.name}], but the resolved name is
            already assigned. This field was not activated.
          MSG
        end

        # Report an error on the assignment and disable the field
        def invalid_assignment!(message)
          GraphQL.logger.tagged('GraphQL') { GraphQL.logger.warn(message.squish) }
        end

    end
  end
end
