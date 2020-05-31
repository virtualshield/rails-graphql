# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold arguments
      module WithArguments
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.inherited_collection(:arguments, default: {})
        end

        def argument(name, base_type, **xargs)
          object = GraphQL::Argument.new(name, base_type, **xargs)

          raise ArgumentError, <<~MSG.squish if arguments.key?(object.name)
            The #{name.inspect} argument is already defined and can't be redifined.
          MSG

          object.validate!
          self.arguments[name] = object
        rescue ArgumentError => e
          defined_at = caller(2)[0]
          raise ArgumentError, e.message + "  " + <<~MSG
            Defined at: #{defined_at}
          MSG
        end
      end
    end
  end
end
