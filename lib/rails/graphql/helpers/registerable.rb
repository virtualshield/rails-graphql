# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module responsible for registering the objects to the type map,
      # which also checks for the uniqueness of the name of things.
      module Registerable
        # Here we define a couple of attributes used by registration
        def self.extended(other)
          other.extend(Helpers::WithNamespace)
          other.extend(Helpers::WithName)
          other.extend(Helpers::WithDescription)

          # Marks if the object is one of those defined on the spec, which
          # marks the object as part of the introspection system
          other.class_attribute :spec_object, instance_accessor: false, default: false
        end

        # Here we wait for the class to be fully loaded so that we can
        # correctly trigger the registration
        def inherited(subclass)
          super if defined? super
          GraphQL.type_map.postpone_registration(subclass)
        end

        # Check if the class is already registered in the typemap
        def registered?
          GraphQL.type_map.object_exist?(self, exclusive: true)
        end

        # The process to register a class and it's name on the index
        def register!
          return if abstract? || gql_name.blank?

          raise DuplicatedError, (+<<~MSG).squish if registered?
            The "#{gql_name}" is already defined, the only way to change its
            definition is by using extensions.
          MSG

          invalid_internal = !spec_object && gql_name.start_with?('__')
          raise NameError, (+<<~MSG).squish if invalid_internal
            The name "#{gql_name}" is invalid. Only internal objects from the
            spec can have a name starting with "__".
          MSG

          super if defined? super
          GraphQL.type_map.register(self)
        end

        # Get or set a list of aliases for this object
        def aliases(*list)
          if list.empty?
            defined?(@aliases) ? @aliases : Set.new
          else
            (@aliases ||= Set.new).merge list.flatten.map do |item|
              item.to_s.underscore.to_sym
            end
          end
        end

        # TODO: When an object is frozen, it was successfully validated
        # alias valid? frozen?

        protected

          # An alias for +description = value.strip_heredoc.chomp+ that can be
          # used as method
          def desc(value)
            self.description = value
          end
      end
    end
  end
end
