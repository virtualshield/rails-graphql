# frozen_string_literal: true

require 'arel/visitors/visitor'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class ToGQL < Arel::Visitors::Visitor
      require_relative 'collectors/to_gql'

      def self.compile(node, **xargs)
        new.compile(node, **xargs)
      end

      def compile(node, collector = Collectors::ToGQL.new, with_descriptions: true) # :nodoc:
        @with_descriptions = with_descriptions
        accept(node, collector).value
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
          visit_description(o, collector)
          collector << o.gql_name
          collector << ': '
        end

        def visit_Rails_GraphQL_Schema(o, collector)
          visit_description(o, collector)
          collector << 'schema'
          visit_directives(o.directives, collector)
          collector.indented(' {', '}') do
          end

          collector.eol
        end

        def visit_Rails_GraphQL_Field_InputField(o, collector)
          visit_Rails_GraphQL_Field(o, collector)
          visit_typed_object(o, collector)
        end

        def visit_Rails_GraphQL_Type_Enum(o, collector)
          visit_description(o, collector)
          collector << 'enum '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            o.values.each { |x| visit_enum_value(o, x, collector) }
          end if o.values.present?

          collector.eol
        end

        def visit_Rails_GraphQL_Type_Input(o, collector)
          visit_description(o, collector)
          collector << 'input '
          collector << o.gql_name
          visit_directives(o.directives, collector)

          collector.indented(' {', '}') do
            o.fields.each_value.with_index do |x, i|
              collector.eol if i > 0
              visit(x, collector)
            end
          end if o.fields.present?

          collector.eol
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
          visit_arguments(o.arguments, collector)
        end

        def visit_Rails_GraphQL_Argument_Instance(o, collector)
          visit_description(o, collector)
          collector << o.gql_name << ': '
          visit_typed_object(o, collector)
        end

        def visit_arguments(list, collector)
          return if list.empty?

          indented = @with_descriptions && list.values.any?(&:description?)

          collector << '('
          collector.eol.indent if indented

          list.each_value.with_index do |x, i|
            if i > 0
              collector.eol if indented
              collector << ', '
            end

            visit_Rails_GraphQL_Argument_Instance(x, collector)
          end

          collector.eol.unindent if indented
          collector << ')'
        end

        def visit_description(o, collector)
          return unless @with_descriptions && o.description?
          collector << o.description.inspect
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

          if o.try(:default_value?)
            collector << ' = ' << o.default_to_json
          end
        end

        def visit(object, collector = nil) # :nodoc:
          object_class = object.is_a?(Module) ? object : object.class
          dispatch_method = dispatch[object_class]
          if collector
            send dispatch_method, object, collector
          else
            send dispatch_method, object
          end
        rescue ::NoMethodError => e
          raise e if respond_to?(dispatch_method, true)
          superklass = object_class.ancestors.find { |klass|
            respond_to?(dispatch[klass], true)
          }
          raise(::TypeError, "Cannot visit #{object_class}") unless superklass
          dispatch[object_class] = dispatch[superklass]
          retry
        end
    end
  end
end
