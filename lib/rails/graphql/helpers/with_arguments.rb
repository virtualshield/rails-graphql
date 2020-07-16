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
          other.alias_method(:all_arguments, :arguments)
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

        def initialize(*args, arguments: nil, **xargs, &block)
          super(*args, **xargs, &block)
          return if arguments.nil?

          @arguments = Array.wrap(arguments).map do |object|
            raise ArgumentError, <<~MSG.squish unless object.is_a?(Argument)
              The given "#{object.inspect}" is not a valid Argument object.
            MSG

            [object.name, object]
          end.to_h
        end

        def initialize_copy(orig)
          super

          @arguments = orig.arguments.transform_values do |item|
            item.dup.tap { |x| x.instance_variable_set(:@owner, self) }
          end
        end

        # Validate all the arguments to make sure the definition is valid
        def validate!(*)
          super if defined? super
          arguments.each_value(&:validate!)
          nil # No exception already means valid
        end

        # See {Argument}[rdoc-ref:Rails::GraphQL::Argument] class.
        def argument(name, base_type, **xargs)
          xargs[:owner] = self
          object = GraphQL::Argument.new(name, base_type, **xargs)

          raise ArgumentError, <<~MSG.squish if has_argument?(object.name)
            The #{name.inspect} argument is already defined and can't be redefined.
          MSG

          arguments[object.name] = object
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end

        # A short cute for arguments named and typed as id
        def id_argument(*args, **xargs, &block)
          name = args.size >= 1 ? args.shift : :id
          xargs[:null] = false unless xargs.key?(:null)
          argument(name, :id, *args, **xargs, &block)
        end

        # Check if a given +name+ is already defined on the list of arguments
        def has_argument?(name)
          arguments.key?(name)
        end
      end
    end
  end
end
