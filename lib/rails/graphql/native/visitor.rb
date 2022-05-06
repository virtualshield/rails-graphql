# frozen_string_literal: true

module Rails
  module GraphQL
    module Native
      # = GraphQL Native Visitor
      #
      # Coordinates the whole process of iterating over the nodes of a GraphQL
      # document and providing information about the collected elements. It has
      # all the bindings but it does not goes into all depths once.
      #
      # The usage is coordinate in other places where the proper place will read
      # its necessary points and pass forward the pointers so that other
      # processes can dig deeper later.
      #
      # TODO: Maybe implement this in C
      class Visitor < FFI::Struct
        CALLBACK_LAYOUT = %i[pointer pointer].freeze

        MACROS = %w[
          document operation_definition variable_definition selection_set field argument
          fragment_spread inline_fragment fragment_definition variable int_value float_value
          string_value boolean_value null_value enum_value list_value object_value object_field
          directive named_type list_type non_null_type name schema_definition
          operation_type_definition scalar_type_definition object_type_definition
          field_definition input_value_definition interface_type_definition
          union_type_definition enum_type_definition enum_value_definition
          input_object_type_definition type_extension_definition directive_definition
        ].freeze

        AUTO_NESTED = %w[document object_value list_type non_null_type].freeze

        ArgumentObject  = Struct.new(:name, :value, :variable)
        DirectiveObject = Struct.new(:name, :arguments)
        FieldObject     = Struct.new(:name, :alias, :arguments, :directives, :selection)
        FragmentObject  = Struct.new(:name, :type, :directives, :selection)
        OperationObject = Struct.new(:name, :kind, :variables, :directives, :selection)
        SpreadObject    = Struct.new(:name, :type, :inline, :directives, :selection)
        VariableObject  = Struct.new(:name, :type, :null, :array, :nullable, :default)

        macros = MACROS.map do |key|
          [
            [    "visit_#{key}", callback(CALLBACK_LAYOUT, :bool)],
            ["end_visit_#{key}", callback(CALLBACK_LAYOUT, :void)],
          ]
        end.flatten(1).to_h
        layout(macros)

        @@callbacks = Visitor.new
        @@instances = Concurrent::Map.new

        MACROS.each do |key|
          @@callbacks["visit_#{key}".to_sym] = ->(node, ref) do
            Visitor.ref_send(key, node, ref)
          end

          @@callbacks["end_visit_#{key}".to_sym] = ->(node, ref) do
            Visitor.ref_send(key, node, ref, prefix: 'end')
          end
        end

        def self.ref_send(key, node, ref, prefix: nil)
          instance = @@instances[ref.read_string]
          method_name = [prefix, 'visit', key].compact.join('_')

          catch :override do
            instance.try(method_name, node)
            prefix.nil? && instance.visit_nested?(key)
          end
        end

        delegate_missing_to('Rails::GraphQL::Native')

        attr_reader :stack, :block

        def initialize
          @data = FFI::MemoryPointer.from_string(SecureRandom.uuid)
          @stack = []
          @visit = nil
          @block = nil
          @error = nil

          @@instances[uuid] = self
        end

        # Remove the instance for the set of instances
        def terminate
          @@instances.delete(uuid)
        end

        # Get the uuid from the string pointer
        def uuid
          @data.read_string
        end

        # Check if it should go deeper into the node
        def visit_nested?(key)
          @error.nil? && (AUTO_NESTED.include?(key) || @visit&.include?(key))
        end

        # Return the last object on the stack being visited
        def object
          stack.last
        end

        # Send the extra needed arguments to the original visitor
        def visit(node)
          Native.visit(node, @@callbacks, @data)
        end

        # Catches if an exception happens inside the block, because visitors on
        # the C lib does not pop such expections
        def safe_call_block(*args)
          block.call(*args)
        rescue Exception => err
          @error ||= err
        end

        # Pre caller for calling the visitor on nodes
        def dispatch(visitors, nodes, &block)
          @visit = visitors
          @block = block

          nodes.each(&method(:visit))
          raise @error unless @error.nil?
        ensure
          @error = @block = @visit = nil
        end

        # ENTRY POINTS

        DEFINITION_VISITORS = %w[operation_definition fragment_definition].freeze
        def collect_definitions(*nodes, &block)
          dispatch(DEFINITION_VISITORS, nodes, &block)
        end

        DIRECTIVES_VISITORS = %w[directive].freeze
        def collect_directives(*nodes, &block)
          dispatch(DIRECTIVES_VISITORS, nodes, &block)
        end

        ARGUMENTS_VISITORS = %w[argument].freeze
        def collect_arguments(*nodes, &block)
          dispatch(ARGUMENTS_VISITORS, nodes, &block)
        end

        VARIABLES_VISITORS = %w[variable_definition].freeze
        def collect_variables(*nodes, &block)
          dispatch(VARIABLES_VISITORS, nodes, &block)
        end

        FIELDS_VISITORS = %w[field fragment_spread inline_fragment].freeze
        def collect_fields(*nodes, &block)
          dispatch(FIELDS_VISITORS, nodes, &block)
        end

        # MAIN VISITORS

        # Add an operation object to the stack
        def visit_operation_definition(node)
          stack << OperationObject.new.tap { |obj| obj.kind = operation_type(node) }
        end

        # Add a fragment object to the stack
        def visit_fragment_definition(_)
          stack << FragmentObject.new
        end

        # Add a field object to the stack
        def visit_field(_)
          stack << FieldObject.new
        end

        # Add a spread object to the stack
        def visit_fragment_spread(_)
          stack << SpreadObject.new
        end

        # Add a spread object to the stack
        def visit_inline_fragment(_)
          stack << SpreadObject.new.tap { |obj| obj.inline = true }
        end

        # BLOCK DISPATCHER VISITORS

        # Send the operation object to the set block
        def end_visit_operation_definition(node)
          safe_call_block(:operation, node, stack.pop)
        end

        # Send the fragment object to the set block
        def end_visit_fragment_definition(node)
          safe_call_block(:fragment, node, stack.pop)
        end

        # Send the directive object to the set block
        def end_visit_directive(_)
          return unless @visit&.include?('directive')

          safe_call_block(stack.pop)
        end

        # Send the argument object to the set block
        def end_visit_argument(_)
          return unless @visit&.include?('argument')

          stack[-2][:value] = stack.pop if stack.size > 1
          safe_call_block(stack.pop)
        end

        # Send the variable object to the set block
        def end_visit_variable_definition(node)
          return unless @visit&.include?('variable_definition')

          stack[-2][:default] = stack.pop unless default_value(node).null?
          safe_call_block(stack.pop, node)
        end

        # Send the field object to the set block
        def end_visit_field(node)
          safe_call_block(:field, node, stack.pop)
        end

        # Send the spread object to the set block
        def end_visit_fragment_spread(node)
          safe_call_block(:spread, node, stack.pop)
        end

        # Send the spread object to the set block
        def end_visit_inline_fragment(node)
          safe_call_block(:spread, node, stack.pop)
        end

        # SECONDARY VISITORS

        # Add a variable definition to the current object
        def visit_variable_definition(node)
          if @visit&.include?('variable_definition')
            stack << VariableObject.new.tap do |obj|
              obj.null = true
              obj.array = false
              obj.nullable = true
            end
          else
            (object[:variables] ||= []) << node
          end
        end

        # Add a directive to the current object
        def visit_directive(node)
          if @visit&.include?('directive')
            stack << DirectiveObject.new
          else
            (object[:directives] ||= []) << node
          end
        end

        # Add a selection set to the current object
        def visit_selection_set(node)
          throw(:override, true) if object.nil?
          object[:selection] = node
        end

        # SHARED VISITORS

        # Set a name into the object
        def visit_name(node)
          object[:alias] = object[:name] unless object[:name].nil?
          object[:name] = node_name(node)
        end

        # Get the type of the object
        def visit_named_type(node)
          object[:type] = node_name(type_name(node))
        end

        # Set the object as an array
        def visit_list_type(_)
          object[:array] = true
        end

        # Set the object as non null or non nullable
        def visit_non_null_type(_)
          object[object[:array] ? :nullable : :null] = false
        end

        # Get an argument information with its given written value
        def visit_argument(node)
          if @visit&.include?('argument')
            stack << ArgumentObject.new
          elsif @visit&.include?('field')
            (object[:arguments] ||= []) << node
          else
            visit(argument_value(node))
            arg_name = node_name(argument_name(node))
            (stack[-2][:arguments] ||= {})[arg_name] = stack.pop
          end
        end

        # Add a variable to the stack
        def visit_variable(node)
          if @visit&.include?('argument')
            object[:variable] = variable_name(node)
          elsif @visit&.include?('variable_definition')
            object[:name] = visit_name(variable_name(node))
          else
            stack << variable_name(node)
          end
        end

        # Add a integer value to the stack
        def visit_int_value(node)
          stack << get_int_value(node)
        end

        # Add a float value to the stack
        def visit_float_value(node)
          stack << get_float_value(node)
        end

        # Add a string value to the stack
        def visit_string_value(node)
          stack << get_string_value(node)
        end

        # Add a boolean value to the stack
        def visit_boolean_value(node)
          stack << get_boolean_value(node).eql?(1)
        end

        # Add a nil value to the stack
        def visit_null_value(*)
          stack << nil
        end

        # Add a enum string-like value to the stack
        def visit_enum_value(node)
          stack << get_enum_value(node)
        end

        # Add a hash value to the stack
        def visit_object_value(*)
          stack << {}
        end

        # Add a hash key value pair to a hash on the stack
        def visit_object_field(node)
          visit(ofield_value(node))
          key = node_name(ofield_name(node))
          stack[-2][key] = stack.pop
        end

        # At the end of a list, change the stack based on the size of the list
        def end_visit_list_value(node)
          stack << size.zero? ? [] : stack.slice!(-list_size(node)..-1)
        end
      end
    end
  end
end
