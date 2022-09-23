# frozen_string_literal: true

require 'arel/visitors/visitor'

# rubocop:disable Naming/MethodParameterName, Naming/MethodName
module Rails
  module GraphQL
    # = GraphQL ToGQL
    #
    # This class can turn any class related to GraphQL into its GraphQL string
    # representation. It was developed more for testing purposes, but it can
    # also used by describing purposes or generating API description pages.
    class ToGQL < Arel::Visitors::Visitor
      DESCRIBE_TYPES = %i[scalar enum input_object interface union object].freeze

      # Trigger a new compile process
      def self.compile(node, **xargs)
        new.compile(node, **xargs)
      end

      # Trigger a new describe process
      def self.describe(schema, **xargs)
        new.describe(schema, **xargs)
      end

      # Describe the given +node+ as GraphQL
      def compile(node, collector = nil, with_descriptions: true)
        collector ||= Collectors::IdentedCollector.new
        @with_descriptions = with_descriptions
        accept(node, collector).value
      end

      # Describe the given +schema+ as GraphQL, with all types and directives
      def describe(schema, collector = nil, with_descriptions: true, with_spec: nil)
        GraphQL.type_map.send(:load_dependencies!, namespace: schema.namespace)

        collector ||= Collectors::IdentedCollector.new
        @with_descriptions = with_descriptions
        @with_spec = with_spec.nil? ? schema.introspection? : with_spec

        accept(schema, collector).eol

        GraphQL.type_map.each_from(schema.namespace, base_class: :Type)
          .group_by(&:kind).values_at(*DESCRIBE_TYPES)
          .each do |items|
            items&.sort_by(&:gql_name)&.each do |item|
              next if !@with_spec && item.internal?

              next visit_Rails_GraphQL_Type_Object(item, collector).eol \
                if item.is_a?(::OpenStruct) && item.object?

              accept(item, collector).eol
            end
          end

        GraphQL.type_map.each_from(schema.namespace, base_class: :Directive)
          .sort_by(&:gql_name).each do |item|
            next if !@with_spec && item.spec_object
            accept(item, collector).eol
          end

        collector.value.chomp
      end

      # Keep visitors in an alphabetical order, but leave instances at the end
      protected

        def visit_Rails_GraphQL_Directive(o, collector)
          return visit_Rails_GraphQL_Directive_Instance(o, collector) \
            unless o.is_a?(Module)

          visit_description(o, collector)
          collector << 'directive @' << o.gql_name
          visit_arguments(o.arguments, collector)
          collector << ' on '
          collector << o.locations.map { |l| l.to_s.upcase }.join(' | ')
          collector.eol
        end

        def visit_Rails_GraphQL_Field(o, collector)
          return if o.disabled?

          visit_description(o, collector)
          collector << o.gql_name

          visit_arguments(o.all_arguments, collector) \
            if o.respond_to?(:all_arguments)

          collector << ': '

          visit_typed_object(o, collector)
          visit_directives(o.directives, collector)
          collector.eol if @with_descriptions
          collector.eol
        end

        def visit_Rails_GraphQL_Mutation(o, collector)
          visit_description(o, collector)
          collector << o.gql_name

          visit_arguments(o.arguments, collector)
          collector << ': '

          visit_typed_object(o, collector)
          collector.eol
        end

        def visit_Rails_GraphQL_Schema(o, collector)
          visit_description(o, collector)
          collector << 'schema'
          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            Helpers::WithSchemaFields::TYPE_FIELD_CLASS.each_key do |key|
              next unless key.eql?(:query) || o.fields_for(key).present?
              name = o.type_name_for(key)

              collector << key.to_s
              collector << ': '
              collector << name
              collector.eol
            end
          end
        end

        def visit_Rails_GraphQL_Field_AssociationField(o, collector)
          return if o.disabled?

          if @with_descriptions
            field = o.instance_variable_get(:@field)
            collector << '# Association of '
            collector << field.owner.name
            collector << '["'
            collector << field.gql_name
            collector << '"]'
            collector.eol
          end

          visit_Rails_GraphQL_Field(o, collector)
        end

        def visit_Rails_GraphQL_Field_ProxyField(o, collector)
          return if o.disabled?

          if @with_descriptions
            field = o.instance_variable_get(:@field)
            collector << '# Proxy of '
            collector << field.owner.name
            collector << '["'
            collector << field.gql_name
            collector << '"]'
            collector.eol
          end

          visit_Rails_GraphQL_Field(o, collector)
        end

        def visit_Rails_GraphQL_Field_OutputField(o, collector)
          visit_Rails_GraphQL_Field(o, collector)
        end

        def visit_Rails_GraphQL_Field_InputField(o, collector)
          visit_Rails_GraphQL_Field(o, collector)
        end

        def visit_Rails_GraphQL_Type_Enum(o, collector)
          visit_description(o, collector)
          collector << 'enum '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            o.values.each { |x| visit_enum_value(o, x, collector) }
          end
        end

        def visit_Rails_GraphQL_Type_Input(o, collector)
          visit_description(o, collector)
          visit_assignment(o, collector)
          collector << 'input '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            o.fields.each_value { |x| visit(x, collector) }
          end
        end

        def visit_Rails_GraphQL_Type_Interface(o, collector)
          visit_description(o, collector)
          visit_assignment(o, collector)
          collector << 'interface '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            o.fields.each_value { |x| visit(x, collector) }
          end
        end

        def visit_Rails_GraphQL_Type_Object(o, collector)
          visit_description(o, collector)
          visit_assignment(o, collector)
          collector << 'type '
          collector << o.gql_name

          if o.interfaces?
            collector << ' implements '
            o.all_interfaces.each_with_index do |x, i|
              collector << ' & ' if i.positive?
              collector << x.gql_name
            end
          end

          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            o.fields.each_value { |x| visit(x, collector) }
          end
        end

        def visit_Rails_GraphQL_Type_Scalar(o, collector)
          visit_description(o, collector)
          collector << 'scalar '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector.eol
        end

        def visit_Rails_GraphQL_Type_Union(o, collector)
          visit_description(o, collector)
          collector << 'union '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector << ' = '
          collector << o.members.map(&:gql_name).join(' | ')
          collector.eol
        end

        def visit_Rails_GraphQL_Directive_Instance(o, collector)
          collector << '@' << o.gql_name
          return unless o.args.to_h.values.any?

          collector << '('
          o.arguments.values.each_with_index do |x, i|
            value = o.args[x.gql_name]
            value = o.args[x.name] if value.nil?
            next if value.nil?

            collector << ', ' if i.positive?
            collector << x.gql_name
            collector << ': '
            collector << x.as_json(value).inspect
          end
          collector << ')'
        end

        def visit_Rails_GraphQL_Argument_Instance(o, collector)
          visit_description(o, collector)
          collector << o.gql_name << ': '
          visit_typed_object(o, collector)
        end

        def visit_arguments(list, collector)
          return if list.blank?

          indented = @with_descriptions && list.values.any?(&:description?)

          collector << '('
          collector.eol.indent if indented

          list.each_value.with_index do |x, i|
            if i.positive?
              collector << ', '
              collector.eol if indented
              collector.eol if @with_descriptions && x.description?
            end

            visit_Rails_GraphQL_Argument_Instance(x, collector)
          end

          collector.eol.unindent if indented
          collector << ')'
        end

        def visit_assignment(o, collector)
          return unless @with_descriptions && o.assigned?

          collector << '# Assigned to '
          collector << o.assigned_to
          collector << ' class'
          collector.eol
        end

        def visit_description(o, collector)
          return unless @with_descriptions && o.description?

          if o.description.lines.size === 1
            collector << o.description.inspect
          else
            collector << '"""'
            collector.eol

            collector << o.description
            collector.eol

            collector << '"""'
          end

          collector.eol
        end

        def visit_directives(list, collector)
          list&.each do |x|
            collector << ' '
            visit_Rails_GraphQL_Directive_Instance(x, collector)
          end
        end

        def visit_enum_value(o, value, collector)
          description = o.value_description[value]
          directives = o.value_directives[value]

          unless !@with_descriptions || description.nil?
            collector << description.inspect
            collector.eol
          end

          collector << value
          visit_directives(directives, collector)
          collector.eol if @with_descriptions
          collector.eol
        end

        def visit_typed_object(o, collector)
          collector << '[' if o.array?
          collector << o.type_klass.gql_name

          if o.array?
            collector << '!' unless o.nullable?
            collector << ']'
          end

          collector << '!' unless o.null?
          collector << ' = ' << o.to_json(o.default) if o.try(:default_value?)
        end

        def visit(object, collector = nil)
          object_class = object.is_a?(Module) ? object : object.class
          dispatch_method = dispatch[object_class]
          if collector
            send dispatch_method, object, collector
          else
            send dispatch_method, object
          end
        rescue ::NoMethodError => e
          raise e if respond_to?(dispatch_method, true)
          superklass = object_class.ancestors.find do |klass|
            respond_to?(dispatch[klass], true)
          end

          raise(::TypeError, +"Cannot visit #{object_class}") unless superklass
          dispatch[object_class] = dispatch[superklass]
          retry
        end
    end
  end
end
# rubocop:enable Naming/MethodParameterName, Naming/MethodName
