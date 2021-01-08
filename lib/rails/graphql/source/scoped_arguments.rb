# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # This is a helper class that allows sources to have scoped-based arguments,
    # meaning that when an argument is present, it triggers the underlying block
    # on the fields where the argument was attached to
    #
    # TODO: Easy the usage of scoped arguments with AR, to map model scopes as
    # arguments using the abilities here provided
    module Source::ScopedArguments
      def self.included(other)
        other.extend(ClassMethods)
      end

      # Extended argument class to be the instance of the scoped
      class Argument < GraphQL::Argument
        attr_reader :block, :fields

        def initialize(*args, on: nil, **xargs, &block)
          super(*args, **xargs)

          @block = block
          @fields = Array.wrap(on).presence
        end

        # Check if the argument should be attached to the given +field+
        def attach_to?(field)
          return true if fields.nil?

          fields.any? do |item|
            (item.is_a?(Symbol) && field.name.eql?(item)) || field.gql_name.eql?(item)
          end
        end
      end

      module ClassMethods # :nodoc:
        # Return the list of scoped params defined
        def scoped_arguments
          defined?(@scoped_arguments) ? @scoped_arguments : {}
        end

        protected

          # Add a new scoped param to the list
          def scoped_argument(param, type = :string, proc_method = nil, **settings, &block)
            block = proc_method if proc_method.present? && block.nil?
            argument = Argument.new(param, type, **settings, owner: self, &block)
            (@scoped_arguments ||= {})[argument.name] = argument
          end

          alias scoped_arg scoped_arguments

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
        return object if event.field.nil? || (args_source = event.send(:args_source)).nil?

        event.data[assigned_to] ||= object unless assigned_to.nil?
        event.field.all_arguments.each_value.inject(object) do |result, argument|
          next result unless argument.respond_to?(:block) && args_source.key?(argument.name)
          send_args = argument.block.arity.eql?(1) ? [args_source[argument.name]] : []

          value = result.instance_exec(*send_args, &argument.block)
          value = value.nil? ? result : value

          assigned_to.nil? ? value : event.data[assigned_to] = value
        end
      end
    end
  end
end
