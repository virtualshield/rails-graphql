# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # = GraphQL EnumType
      #
      # Enum types, like scalar types, also represent leaf values in a GraphQL
      # type system. However Enum types describe the set of possible values.
      # See http://spec.graphql.org/June2018/#EnumTypeDefinition
      class Enum < Type
        extend ActiveSupport::Autoload

        setup! leaf: true, input: true, output: true

        autoload :DirectiveLocationEnum
        autoload :TypeKindEnum

        autoload :PaginationModeEnum

        # Define the methods for accessing the values attribute
        inherited_collection :values

        # Define the methods for accessing the description of each enum value
        inherited_collection :value_description, type: :hash

        # Define the methods for accessing the directives of each enum value
        inherited_collection :value_directives, type: :hash_set

        class << self
          # Mark the enum as indexed, allowing values being set by number
          def indexed!
            @indexed = true
          end

          # Checks if the enum was marked as indexed
          def indexed?
            defined?(@indexed) && @indexed.present?
          end

          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            (valid_token?(value, :enum) && all_values.include?(value.to_s)) ||
              (value.is_a?(String) && all_values.include?(value)) ||
              (allow_string_input? && valid_token?(value, :string) &&
                all_values.include?(value.to_s[1..-2]))
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
            return all_values.drop(value).first if indexed? && value.is_a?(Numeric)
            value.to_s.underscore.upcase
          end

          # Turn a user input of this given type into an ruby object
          def deserialize(value)
            if valid_token?(value, :enum)
              new(value.to_s)
            elsif allow_string_input? && valid_token?(value, :string)
              new(value[1..-2])
            elsif valid_input?(value)
              new(value)
            end
          end

          # Use the instance as decorator
          def decorate(value)
            deserialize(as_json(value))
          end

          # Use this method to add values to the enum type
          #
          # ==== Options
          #
          # * <tt>:desc</tt> - The description of the enum value (defaults to nil).
          # * <tt>:description</tt> - Alias to the above.
          # * <tt>:directives</tt> - The list of directives associated with the value
          #   (defaults to nil).
          # * <tt>:deprecated</tt> - A shortcut that auto-attach a @deprecated
          #   directive to the value. A +true+ value simple attaches the directive,
          #   but provide a string so it can be used as the reason of the deprecation.
          #   See {DeprecatedDirective}[rdoc-ref:Rails::GraphQL::Directive::DeprecatedDirective]
          #   (defaults to false).
          def add(value, desc: nil, description: nil, directives: nil, deprecated: false)
            value = value&.to_s
            raise ArgumentError, (+<<~MSG).squish unless value.is_a?(String) && !value.empty?
              The "#{value}" is invalid.
            MSG

            value = value.upcase
            raise ArgumentError, (+<<~MSG).squish if all_values&.include?(value)
              The "#{value}" is already defined for #{gql_name} enum.
            MSG

            directives = ::Array.wrap(directives)
            directives << Directive::DeprecatedDirective.new(
              reason: (deprecated.is_a?(String) ? deprecated : nil),
            ) if deprecated.present?

            directives = GraphQL.directives_to_set(directives,
              location: :enum_value,
              source: self,
            )

            desc = description if desc.nil?

            values << value
            value_description[value] = desc unless desc.nil?
            value_directives[value] = directives if directives
          end

          # Check if a given +value+ is using a +directive+
          def value_using?(value, directive)
            raise ArgumentError, (+<<~MSG).squish unless directive < GraphQL::Directive
              The provided #{item_or_symbol.inspect} is not a valid directive.
            MSG

            all_value_directives.try(:[], as_json(value))&.any?(directive) || false
          end

          # Build a hash with deprecated values and their respective reason for
          # logging and introspection purposes
          def all_deprecated_values
            @all_deprecated_values ||= begin
              all_value_directives&.each&.with_object({}) do |(value, dirs), hash|
                obj = dirs&.find { |dir| dir.is_a?(Directive::DeprecatedDirective) }
                hash[value] = obj.args.reason || true unless obj.nil?
              end
            end.freeze
          end

          def inspect
            return super if self.eql?(Type::Enum)

            values = all_values.to_a
            (+<<~INFO).squish << '>'
              #<GraphQL::Enum #{gql_name}
              (#{values.size})
              {#{values.to_a.join(' | ')}}
              #{inspect_directives}
            INFO
          end

          private

            def allow_string_input?
              GraphQL.config.allow_string_as_enum_input
            end
        end

        attr_reader :value

        delegate :to_s, :inspect, to: :@value

        # TODO: Maybe add delegate missing

        def initialize(value)
          @value = value
        end

        # Allow comparing the current value with another formats
        def ==(other)
          case other
          when Symbol then to_sym == other
          when Numeric then to_i == other
          else @value == other
          end
        end

        # Use lower case for symbolized value
        def to_sym
          @value.downcase.to_sym
        end

        # Allow finding the indexed position of the value
        def to_i
          values.find_index(@value)
        end

        # Checks if the current value is valid
        def valid?
          self.class.valid_output?(@value)
        end

        # Gets all the description of the current value
        def description
          return unless @value
          return @description if defined?(@description)
          @description = all_value_description.try(:[], @value)
        end

        # Gets all the directives associated with the current value
        def directives
          return unless @value
          return @directives if defined?(@directives)
          @directives = all_value_directives.try(:[], @value)
        end

        # Checks if the current value is marked as deprecated
        def deprecated?
          directives&.any?(Directive::DeprecatedDirective) || false
        end

        # Return the deprecated reason
        def deprecated_reason
          directives&.find do |dir|
            dir.is_a?(Directive::DeprecatedDirective)
          end&.args&.reason
        end
      end
    end
  end
end
