# frozen_string_literal: true

module Rails
  module GraphQL
    # This is a helper class that allows sources to have scoped-based arguments,
    # meaning that when an argument is present, it triggers the underlying block
    # on the fields where the argument was attached to
    module Source::ScopedArguments
      def self.included(other)
        other.extend(ClassMethods)
      end

      # Extended argument class to be the instance of the scoped
      class Argument < GraphQL::Argument
        def initialize(*args, block:, on: nil, **xargs)
          super(*args, **xargs)

          @block = block
          @fields = on
        end

        # Apply the argument block to the given object, using or not the value
        def apply_to(object, value)
          callable = @block.is_a?(Symbol) ? object.method(@block) : @block
          raise ::ArgumentError, (+<<~MSG) unless callable.respond_to?(:call)
            Unable to call "#{@block.inspect}" on #{object.class}.
          MSG

          args = (callable.arity == 1 || callable.arity == -1) ? [value] : nil

          return callable.call(*args) if callable.is_a?(Method)
          object.instance_exec(*args, &callable)
        end

        # Check if the argument should be attached to the given +field+
        def attach_to?(field)
          return true if @fields.nil?

          GraphQL.enumerate(@fields).any? do |item|
            (item.is_a?(Symbol) && field.name.eql?(item)) || field.gql_name.eql?(item)
          end
        end
      end

      module ClassMethods
        # Return the list of scoped params defined
        def scoped_arguments
          defined?(@scoped_arguments) ? @scoped_arguments : {}
        end

        # Hook into the attach fields process to attach the scoped arguments
        def attach_fields!(type, fields)
          attach_scoped_arguments_to(fields.values)
          super
        end

        protected

          # Add a new scoped param to the list
          def scoped_argument(param, type = :string, proc_method = nil, **settings, &block)
            block = proc_method if proc_method.present? && block.nil?
            argument = Argument.new(param, type, **settings, owner: self, block: block)
            (@scoped_arguments ||= {})[argument.name] = argument
          end

          alias scoped_arg scoped_argument

          # Helper method to attach the scoped arguments to a given +field+
          def attach_scoped_arguments_to(*fields, safe: true)
            fields = fields.flatten.compact
            return if fields.blank?

            scoped_arguments.each_value do |argument|
              fields.each do |item|
                item.ref_argument(argument) if argument.attach_to?(item)
              rescue DuplicatedError
                raise unless safe
              end
            end
          end
      end

      # Find all the executable arguments attached to the running field and
      # call them with the given object
      def inject_scopes(object, assigned_to = nil)
        return object if event.field.nil? || (field_args = event.field.all_arguments).blank?

        args_source = event.send(:args_source)
        event.data[assigned_to] ||= object unless assigned_to.nil?
        field_args.each_value.inject(object) do |result, argument|
          arg_value = args_source.key?(argument.name) \
            ? args_source[argument.name] \
            : argument.default

          next result if arg_value.nil? || !argument.is_a?(Argument)

          value = argument.apply_to(result, arg_value)
          value = value.nil? ? result : value

          assigned_to.nil? ? value : event.data[assigned_to] = value
        end
      end
    end
  end
end
