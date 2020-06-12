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

        attr_reader :registered, :user_data, :stack

        def initialize
          @user_data = FFI::MemoryPointer.new(:bool)
          @registered = []
          @stack = []
        end

        require_relative 'visitor/definitions'

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
      end
    end
  end
end


