# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module that allows other objects to hold directives during the
      # definition process
      module WithDirectives
        def self.extended(other)
          other.extend(Helpers::InheritedCollection)
          other.extend(WithDirectives::DirectiveLocation)
          other.inherited_collection(:directives)
        end

        def self.included(other)
          other.extend(WithDirectives::DirectiveLocation)
          other.define_method(:directives) { @directives ||= Set.new }
          other.define_method(:all_directives) { @directives if defined?(@directives) }
          other.define_method(:directives?) { defined?(@directives) && @directives.present? }
        end

        def initialize_copy(orig)
          super

          return if orig.directives.nil?
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
            raise ArgumentError, +'Directive location is already defined' \
              unless directive_location.nil?

            @directive_location = value
          end
        end

        # Use this method to assign directives to the given definition. You can
        # also provide a symbol as a first argument and extra named-arguments
        # to auto initialize a new instance of that directive.
        def use(item_or_symbol, *list, **xargs)
          if item_or_symbol.is_a?(Symbol)
            directive = fetch!(item_or_symbol)
            raise ArgumentError, (+<<~MSG).squish unless directive < GraphQL::Directive
              Unable to find the #{item_or_symbol.inspect} directive.
            MSG

            list = [directive.new(**xargs)]
          else
            list << item_or_symbol
          end

          directives.merge(GraphQL.directives_to_set(list, all_directives, source: self))
          self
        rescue DefinitionError => e
          raise e.class, +"#{e.message}\n  Defined at: #{caller(2)[0]}"
        end

        # Check whether a given directive is being used
        def using?(item)
          directive = (item.is_a?(Symbol) || item.is_a?(String)) ? fetch!(item) : item
          raise ArgumentError, (+<<~MSG).squish unless directive < GraphQL::Directive
            The provided #{item.inspect} is not a valid directive.
          MSG

          !!all_directives&.any?(directive)
        end

        alias has_directive? using?

        # TODO: Maybe implement a method to find a specific directive

        # Override the +all_listeners+ method since callbacks can eventually be
        # attached to objects that have directives, which then they need to
        # be combined
        def all_directive_listeners
          inherited = super if defined?(super)
          return inherited unless directives?

          current = all_directives.map(&:all_listeners).compact.reduce(:+)
          inherited.nil? ? current : inherited + current
        end

        alias all_listeners all_directive_listeners

        # Make sure to consider directive listeners while checking for listeners
        def directive_listeners?
          (defined?(super) && super) || all_directives&.any?(&:listeners?)
        end

        alias listeners? directive_listeners?

        # Override the +all_events+ method since callbacks can eventually be
        # attached to objects that have directives, which then they need to
        # be combined
        def all_directive_events
          inherited = super if defined?(super)
          return inherited unless directives?

          all_directives.inject(inherited || {}) do |result, directive|
            next result if (val = directive.all_events).blank?
            Helpers.merge_hash_array(result, val)
          end
        end

        alias all_events all_directive_events

        # Make sure to consider directive events while checking for events
        def directive_events?
          (defined?(super) && super) || all_directives&.any?(&:events?)
        end

        alias events? directive_events?

        # Validate all the directives to make sure the definition is valid
        def validate!(*)
          super if defined? super

          return unless defined? @directives
          @directives.each(&:validate!)
          @directives.freeze
        end

        protected

          # Helper method to inspect the directives
          def inspect_directives
            all_directives&.map(&:inspect)&.join(' ')
          end

        private

          # Find a directive for its symbolized name
          def fetch!(name)
            GraphQL.type_map.fetch!(name,
              base_class: :Directive,
              namespaces: namespaces,
              prevent_register: try(:owner) || self,
            )
          end
      end
    end
  end
end
