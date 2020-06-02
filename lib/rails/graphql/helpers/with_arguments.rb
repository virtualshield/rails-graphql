# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold arguments
      module WithArguments
        def self.extended(other)
          other.extend(WithArguments::ClassMethods)
          other.define_singleton_method(:arguments) { @arguments ||= {} }
          other.delegate(:arguments, to: :class)
        end

        def self.included(other)
          other.define_method(:arguments) { @arguments ||= {} }
        end

        module ClassMethods # :nodoc: all
          def inherited(subclass)
            super if defined? super
            return if arguments.empty?

            new_arguments = arguments.transform_values do |item|
              item.dup.tap { |x| x.instance_variable_set(:@owner, subclass) }
            end

            subclass.instance_variable_set(:@arguments, new_arguments)
          end
        end

        def initialize_copy(orig)
          super

          @arguments = orig.arguments.transform_values do |item|
            item.dup.tap { |x| x.instance_variable_set(:@owner, self) }
          end
        end

        # Validate all the arguments to make sure the definition is valid
        def validate!
          super if defined? super
          arguments.each_value(&:validate!)
        end

        # See {Argument}[rdoc-ref:Rails::GraphQL::Argument] class.
        def argument(name, base_type, **xargs)
          xargs[:owner] = self
          object = GraphQL::Argument.new(name, base_type, **xargs)

          raise ArgumentError, <<~MSG.squish if arguments.key?(object.name)
            The #{name.inspect} argument is already defined and can't be redifined.
          MSG

          arguments[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end
      end
    end
  end
end
