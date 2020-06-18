# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct
        CALLBACK_LAYOUT = %i[pointer pointer].freeze

        macros = Pathname.new(__dir__).join('../../../../')
        macros = macros.join('ext/graphqlparser/c/GraphQLAstForEachConcreteType.h')
        MACROS = File.foreach(macros.to_s).map do |line|
          line.match(/MACRO\(\w+, (\w+)\)/).try(:[], 1)
        end.compact.freeze

        macros = MACROS.map do |key|
          [
            [    "visit_#{key}", callback(CALLBACK_LAYOUT, :bool)],
            ["end_visit_#{key}", callback(CALLBACK_LAYOUT, :void)],
          ]
        end.flatten(1).to_h
        layout(macros)

        delegate_missing_to('Rails::GraphQL::Native')

        attr_reader :registered, :user_data, :stack

        def initialize
          @user_data = FFI::MemoryPointer.new(:bool)
          @registered = []
          @stack = []
        end

        require_relative 'visitor/definitions'
        require_relative 'visitor/directives'
        require_relative 'visitor/variables'
        require_relative 'visitor/debug'

        private

          # Register a function to the visitor
          def register(key, &block)
            registered << key
            self[key] = block
          end

          # Unregister a list or all registered function visitors
          def unregister!
            registered.map { |key| self[key.to_sym] = nil }
            registered.clear
          end

          # Return the last object on the stack being visited
          def object
            stack.last
          end

          # Run a given block then unregister all the visitors
          def setup_for(method_name)
            send("setup_for_#{method_name}")
            yield

            unregister!
            nil
          end

          # An abstract setup for named stuff
          def setup_with_name
            register(:visit_name) do |node|
              (object[:name] = node_name(node))                                 && true
            end
          end

          # An abstract setup for named type stuff
          def setup_with_type
            register(:visit_named_type) do |node|
              (object[:type] = node_name(type_name(node)))                      && false
            end
          end

          # An abstract setup for stuff with arguments
          def setup_with_arguments
            setup_with_value

            register(:visit_argument) do |node|
              visit(argument_value(node), self, user_data)
              (stack[-2][node_name(argument_name(node))] = stack.pop)           && false
            end
          end

          # An abstract setup for stuff with values
          def setup_with_value
            register(:visit_int_value) do |node|
              (stack << get_int_value(node))                                    && false
            end

            register(:visit_float_value) do |node|
              (stack << get_float_value(node))                                  && false
            end

            register(:visit_string_value) do |node|
              (stack << get_string_value(node))                                 && false
            end

            register(:visit_boolean_value) do |node|
              (stack << get_boolean_value(node))                                && false
            end

            register(:visit_null_value) do |node|
              (stack << nil)                                                    && false
            end

            register(:visit_enum_value) do |node|
              (stack << get_enum_value(node))                                   && false
            end

            register(:visit_object_value) do |node|
              (stack << {})                                                     && true
            end

            register(:visit_object_field) do |node|
              visit(ofield_value(node), self, user_data)
              (stack[-2][node_name(ofield_name(node))] = stack.pop)             && false
            end

            register(:end_visit_list_value) do |node|
              size = list_size(node)
              stack << (size.zero? ? [] : stack.slice!(-(size)..-1))
            end
          end
      end
    end
  end
end
