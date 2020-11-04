# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module responsible for name stuff and also responsible for
      # registering the objects to the type map, which also checks for the
      # uniqueness of the name of things.
      module Registerable
        NAME_EXP = /GraphQL::(?:Type::\w+::|Directive::)?([:\w]+?)([A-Z][a-z]+)?\z/.freeze

        # Here we define a couple of attributes used by registration
        def self.extended(other)
          other.extend(Registerable::ClassMethods)
          other.extend(Helpers::WithNamespace)

          # If a type is marked as abstract, it's then used as a base and it
          # won't appear in the introspection
          other.class_attribute :abstract, instance_writer: false, default: false

          # Marks if the object is one of those defined on the spec, which
          # marks the object as part of the introspection system
          other.class_attribute :spec_object, instance_writer: false, default: false

          # The given description of the type
          other.class_attribute :description, instance_writer: false
        end

        module ClassMethods # :nodoc: all
          # Here we wait for the class to be fully loaded so that we can
          # correctly trigger the registration
          def inherited(subclass)
            super if defined? super
            return if subclass.try(:abstract)
            GraphQL.type_map.postpone_registration(subclass)
          end

          # Check if the class is already registered in the typemap
          def registered?
            GraphQL.type_map.object_exist?(self, exclusive: true)
          end

          # The process to register a class and it's name on the index
          def register!
            return if abstract? || gql_name.blank?

            raise DuplicatedError, <<~MSG.squish if registered?
              The "#{gql_name}" is already defined, the only way to change its
              definition is by using extensions.
            MSG

            invalid_internal = !spec_object && gql_name.start_with?('__')
            raise NameError, <<~MSG.squish if invalid_internal
              The name "#{gql_name}" is invalid. Only internal objects from the
              spec can have a name starting with "__".
            MSG

            super if defined? super
            GraphQL.type_map.register(self).method(:validate!)
          end
        end

        # Return the name of the object as a GraphQL name
        def gql_name
          @gql_name ||= begin
            name.match(NAME_EXP).try(:[], 1)&.tr(':', '')
          end unless anonymous?
        end

        alias graphql_name gql_name

        # Return the name of the object as a symbol
        def to_sym
          @gql_key ||= gql_name&.underscore&.to_sym
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

        protected

          # An alias for +description = value.strip_heredoc.chomp+ that can be
          # used as method
          def desc(value)
            self.description = value.strip_heredoc.chomp
          end

          # Change the gql name of the object
          def rename!(name)
            @gql_name = name
          end
      end
    end
  end
end
