# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL EnumType
      #
      # Enum types, like scalar types, also represent leaf values in a GraphQL
      # type system. However Enum types describe the set of possible values.
      # See http://spec.graphql.org/June2018/#EnumTypeDefinition
      class Enum < Type
        extend ActiveSupport::Autoload
        extend Helpers::LeafFromAr

        setup! leaf: true, input: true, output: true
        set_ar_type! :enum

        eager_autoload do
          autoload :DirectiveLocationEnum
          autoload :TypeKindEnum
        end

        # Define the methods for accessing the values attribute
        inherited_collection :values

        # Define the methods for accessing the description of each enum value
        inherited_collection :value_description, type: :hash

        # Define the methods for accessing the directives of each enum value
        inherited_collection :value_directives, type: :hash

        class << self
          # Mark the enum as indexed, allowing values being set by number
          def indexed!
            @indexed = true
          end

          # Checks if the enum was marked as indexed
          def indexed?
            @indexed.present?
          end

          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value.is_a?(String) && all_values.include?(value)
          end

          # Check if a given value is a valid non-serialized output
          def valid_output?(value)
            all_values.include?(as_json(value))
          end

          # Transforms the given value to its representation in a JSON string
          def to_json(value)
            as_json(value)&.inspect
          end

          # Transforms the given value to its representation in a Hash object
          def as_json(value)
            return if value.nil?
            return value.to_s if value.is_a?(self)
            return all_values[value] if indexed? && value.is_a?(Numeric)
            value.to_s.underscore.upcase
          end

          # Turn a user input of this given type into an ruby object
          def deserialize(value)
            new(value)
          end

          # Use the instance as decorator
          def decorate(value)
            new(as_json(value))
          end

          # Use this method to add values to the enum type
          #
          # ==== Options
          #
          # * <tt>:desc</tt> - The description of the enum value (defaults to nil).
          # * <tt>:directives</tt> - The list of directives associated with the value
          #   (defaults to nil).
          # * <tt>:deprecated</tt> - A shortcut that auto-attach a @deprecated
          #   directive to the value. A +true+ value simple attaches the directive,
          #   but provide a string so it can be used as the reason of the deprecation.
          #   See {DeprecatedDirective}[rdoc-ref:Rails::GraphQL::Directive::DeprecatedDirective]
          #   (defaults to false).
          def add(value, desc: nil, directives: nil, deprecated: false)
            value = as_json(value)

            raise ArgumentError, <<~MSG.squish unless value.is_a?(String) && value.present?
              The "#{value}" is invalid.
            MSG

            raise ArgumentError, <<~MSG.squish if all_values.include?(value)
              The "#{value}" is already defined for #{gql_name} enum.
            MSG

            directives = Array.wrap(directives)
            directives << deprecated_klass.new(
              reason: (deprecated.is_a?(String) ? deprecated : nil),
            ) if deprecated.present?

            directives = GraphQL.directives_to_set(directives,
              location: :enum_value,
              source: self,
            )

            self.values << value
            self.value_description[value] = desc unless desc.nil?
            self.value_directives[value] = directives
          end

          # Check if a given +value+ is using a +directive+
          def value_using?(value, directive)
            raise ArgumentError, <<~MSG.squish unless directive < GraphQL::Directive
              The provided #{item_or_symbol.inspect} is not a valid directive.
            MSG

            value_directives[to_hash(value)]&.any? { |item| item.is_a?(directive) }
          end

          # Build a hash with deprecated values and their respective reason for
          # logging and introspection purposes
          def all_deprecated_values
            @all_deprecated_values ||= begin
              all_value_directives.to_a.inject({}) do |list, (value, dirs)|
                next list unless obj = dirs.find do |dir|
                  dir.is_a?(deprecated_klass)
                end

                list.merge(value => obj.args.reason)
              end
            end.freeze
          end

          # This returns the field directives and all value directives
          def all_directives
            super + all_value_directives.each_value.reduce(:+)
          end

          def inspect # :nodoc:
            <<~INFO.squish + '>'
              #<GraphQL::Enum #{gql_name}
              (#{all_values.size})
              {#{all_values.to_a.join(' | ')}}
            INFO
          end

          private

            def deprecated_klass
              Directive::DeprecatedDirective
            end
        end

        attr_reader :value

        delegate :to_s, :inspect, to: :@value

        def initialize(value)
          @value = value
        end

        # Use lower canse for symbolized value
        def to_sym
          @value.downcase.to_sym
        end

        # Allow finding the indexed position of the value
        def to_i
          self.class.all_values.index(@value)
        end

        # Checks if the current value is valid
        def valid?
          self.class.valid_output?(@value)
        end

        # Gets all the description of the current value
        def description
          @description ||= @value && self.class.all_description[@value]
        end

        # Gets all the directives associated with the current value
        def directives
          @directives ||= @value && self.class.all_directives[@value]
        end

        # Checks if the current value is marked as deprecated
        def deprecated?
          self.class.all_deprecated_values.include?(@value)
        end

        # Return the deprecated reason
        def deprecated_reason
          deprecated_directive&.args&.reason
        end

        private

          # Find and store the directive that marked the current value as
          # deprecated
          def deprecated_directive
            @deprecated_directive ||= directives.find do |dir|
              dir.is_a?(Directive::DeprecatedDirective)
            end
          end

      end
    end
  end
end
