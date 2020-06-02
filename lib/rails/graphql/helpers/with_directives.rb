# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold directives during the
      # defition process
      module WithDirectives
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.extend(WithDirectives::DirectiveLocation)
          other.inherited_collection(:directives)
        end

        def self.included(other)
          other.extend(WithDirectives::DirectiveLocation)
          other.define_method(:directives) { @directives ||= Set.new }
          other.class_attribute(:directive_location, instance_writer: false)
          other.delegate(:directive_location, to: :class)
        end

        def initialize_copy(orig)
          super

          @directives = orig.directives.dup
        end

        module DirectiveLocation
          # Return the symbol that represents the location that the directives
          # must have in order to be added to the list
          def directive_location
            defined?(@directive_location) \
              ? @directive_location \
              : superclass.try(:directive_location)
          end

          # Use this once to define the directive location
          def directive_location=(value)
            raise ArgumentError, 'Directive location is already defined' \
              unless directive_location.nil?

            @directive_location = value
          end
        end

        # Use this method to assign directives to the given definition
        # TODO: Check if the first argument is an instance of a directive,
        # otherwise allow +key, **xargs+ as an overload, where the key is the
        # name of the directive (and found using +GraphQL.type_map+) and the
        # +**xargs+ used to initialize the directive
        def use(*list)
          current = try(:all_directives) || directives
          directives.merge(GraphQL.directives_to_set(list, current, directive_location))
        rescue DefinitionError => e
          raise e.class, e.message + "\n  Defined at: #{caller(2)[0]}"
        end
      end
    end
  end
end
