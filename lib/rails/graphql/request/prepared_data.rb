# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Bypass Data
      #
      # This class works in collaboration with the prepare stage of a request
      # execution. In that stage, the strategy must check if the request already
      # have a prepared data for the field. The field can result in a instance
      # of this class, which than bypasses the prepare stage by grabbing the
      # next value from here
      class PreparedData
        SCHEMA_BASED = Helpers::WithSchemaFields::TYPE_FIELD_CLASS.keys.freeze
        NULL = Object.new.freeze

        REPEAT_OPTIONS = {
          true => true,
          false => 1,
          cycle: true,
          always: true,
        }.freeze

        # Look up the given +field+ using the request as a reference. It accepts
        # any +Rails::GraphQL::Field+ or a string where +"query.create_user"+
        # means a query field on the request schema with +create_user+ as name,
        # or +create_user+ as gql_name, and "User.devices" will use the schema
        # of the request to lookup the type +"User"+ and then pick the field
        # +devices+
        def self.lookup(request, field)
          return field if field.is_a?(GraphQL::Field)

          source, name = field.to_s.split('.')
          return if source.nil? || name.nil?

          if SCHEMA_BASED.any? { |item| item.to_s == source }
            request.schema.find_field!(source.to_sym, name)
          elsif (type = request.schema.find_type!(source)).is_a?(Helpers::WithFields)
            type.find_field!(name)
          else
            field
          end
        rescue NotFoundError
          # Return the original value, maybe it will be resolved somewhere else
          field
        end

        def initialize(field, value, repeat: 1)
          # Check if it has a valid field
          raise ::ArgumentError, (+<<~MSG).squish unless field.is_a?(GraphQL::Field)
            Unable to setup a prepared data for "#{field.inspect}".
            You must provide a valid field.
          MSG

          @field = field
          @value = value
          @array = value.is_a?(Array) && !field.array?
          @repeat =
            case repeat
            when Numeric then repeat
            when Enumerator then repeat.size
            else REPEAT_OPTIONS[repeat]
            end
        end

        # Add one more item to the list of data
        def push(*values)
          return @value += values if @array
          @value = [@value, *values]
        end

        # The the whole value, because the prepare stage always deal with all
        # the information available
        def all
          @field.array? ? Array.wrap(@value) : @value
        end

        # Get the enumerable of the whole value
        def enum
          @enum ||= (@array ? @value.to_enum : @value.then)
        end

        # Get the next value, take into consideration the value on repeat
        def next
          value = enum.next
          @field.array? ? Array.wrap(value) : value
        rescue StopIteration
          if @repeat == true || (@repeat != false && (@repeat -= 1) > 0)
            enum.rewind
            self.next
          else
            NULL
          end
        end
      end
    end
  end
end
