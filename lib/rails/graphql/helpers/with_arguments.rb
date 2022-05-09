# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module that allows other objects to hold arguments
      module WithArguments
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.extend(WithArguments::ClassMethods)
          other.inherited_collection(:arguments, type: :hash)
        end

        def self.included(other)
          other.define_method(:arguments) do
            defined?(@arguments) ? @arguments : {}
          end

          other.define_method(:all_arguments) do
            arguments
          end

          other.define_method(:arguments?) do
            !!defined?(@arguments)
          end
        end

        module ClassMethods
          def inherited(subclass)
            super if defined? super
            return if arguments.empty?

            new_arguments = Helpers.dup_all_with_owner(arguments.transform_values, subclass)
            subclass.instance_variable_set(:@arguments, new_arguments)
          end
        end

        def initialize(*args, arguments: nil, **xargs, &block)
          @arguments = arguments.then.map do |object|
            raise ArgumentError, (+<<~MSG).squish unless object.is_a?(Argument)
              The given "#{object.inspect}" is not a valid Argument object.
            MSG

            [object.name, Helpers.dup_with_owner(object, self)]
          end.to_h unless arguments.nil?

          super(*args, **xargs, &block)
        end

        def initialize_copy(orig)
          super

          @arguments = Helpers.dup_all_with_owner(orig.arguments.transform_values, self)
        end

        # Check if all the arguments are compatible
        def =~(other)
          super && other.respond_to?(:all_arguments) && match_arguments?(other)
        end

        # See {Argument}[rdoc-ref:Rails::GraphQL::Argument] class.
        def argument(name, base_type, **xargs)
          xargs[:owner] = self
          object = GraphQL::Argument.new(name, base_type, **xargs)

          raise DuplicatedError, (+<<~MSG).squish if has_argument?(object.name)
            The #{name.inspect} argument is already defined and can't be redefined.
          MSG

          (@arguments ||= {})[object.name] = object
        rescue DefinitionError => e
          raise e.class, +"#{e.message}\n  Defined at: #{caller(2)[0]}"
        end

        # Since arguments' owner are more flexible, their instances can be
        # directly associated to objects that have argument
        def ref_argument(object)
          raise ArgumentError, (+<<~MSG).squish unless object.is_a?(GraphQL::Argument)
            The given object #{object.inspect} is not a valid argument.
          MSG

          raise DuplicatedError, (+<<~MSG).squish if has_argument?(object.name)
            The #{object.name.inspect} argument is already defined and can't be redefined.
          MSG

          (@arguments ||= {})[object.name] = object
        rescue DefinitionError => e
          raise e.class, +"#{e.message}\n  Defined at: #{caller(2)[0]}"
        end

        # A short cute for arguments named and typed as id
        def id_argument(*args, **xargs, &block)
          name = args.size >= 1 ? args.shift : :id
          xargs[:null] = false unless xargs.key?(:null)
          argument(name, :id, *args, **xargs, &block)
        end

        # Check if a given +name+ is already defined on the list of arguments
        def has_argument?(name)
          defined?(@arguments) && @arguments.key?(name)
        end

        # Validate all the arguments to make sure the definition is valid
        def validate!(*)
          super if defined? super

          return unless defined? @arguments
          @arguments.each_value(&:validate!)
          @arguments.freeze
        end

        protected

          # Show all the arguments as their inspect version
          def inspect_arguments
            args = all_arguments.each_value.map(&:inspect)
            args.presence && +"(#{args.join(', ')})"
          end

          # Check the equivalency of arguments
          def match_arguments?(other)
            l_args, r_args = all_arguments, other.all_arguments
            l_args.size <= r_args.size && l_args.all? { |key, arg| arg =~ r_args[key] }
          end
      end
    end
  end
end
