# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Component Operation
      #
      # This class holds information about a given operation. This will guide
      # the validation and execution of it.
      class Component::Operation < Component
        extend ActiveSupport::Autoload

        include SelectionSet
        include Directives

        class << self
          alias type kind

          # Helper method to initialize an operation given the node
          def build(request, node)
            request.build(const_get(node.type.to_s.classify), request, node)
          end

          # Rewrite the kind to always return +:operation+
          def kind
            :operation
          end

          # Defines if the current operation is a query type
          def query?
            false
          end

          # Defines if the current operation is a mutation type
          def mutation?
            false
          end

          # Defines if the current operation is a subscription type
          def subscription?
            false
          end
        end

        # Query is default behavior, so it doesn't need a whole class
        Query    = Class.new(self) { redefine_singleton_method(:query?)    { true } }
        Mutation = Class.new(self) { redefine_singleton_method(:mutation?) { true } }

        autoload :Subscription

        delegate :type, :query?, :mutation?, :subscription?, to: :class
        delegate :schema, to: :strategy

        attr_reader :name, :variables, :arguments, :request

        alias gql_name name
        alias operation itself
        alias vars variables
        alias all_arguments arguments

        def initialize(request, node)
          @name = node[1]
          @request = request

          super(node)

          check_invalid_operation!
        end

        # The list of fields comes from the +fields_for+ of the same type as
        # the +type+ of the operation
        def fields_source
          schema.fields_for(type)
        end

        # Allow accessing the fake type form the schema. It's used for
        # inline spreads without a specified type
        def type_klass
          schema.public_send("#{type}_type")
        end

        # The typename is always based on the fake name used for the set of
        # schema fields
        def typename
          schema.type_name_for(type)
        end

        # Support memory object to save information across the iteration
        def memo
          @memo ||= OpenStruct.new
        end

        # Add a empty entry if the operation has a name
        def resolve_invalid
          response.safe_add(name, nil) if stacked_selection?
        end

        # Stores all the used variables to report not used ones
        def used_variables
          @used_variables ||= Set.new
        end

        # Stores all the used fragments
        def used_fragments
          @used_fragments ||= Set.new
        end

        # A fast way to access the correct display name for log or errors
        def log_source
          @log_source ||= name.blank? ? type : +"#{name} #{type}"
        end

        # The hash of operations must take into consideration the used fragments
        def hash
          return super unless defined?(@used_fragments)

          super ^ used_fragments.reduce(0) do |value, fragment|
            request.fragments[fragment].hash
          end
        end

        # Build the cache object
        def cache_dump
          super.merge(type: self.class)
        end

        # Organize from cache data
        def cache_load(data)
          @name = data[:node][1]

          super
        end

        protected

          # Trigger an specific event with the +type+ of the operation
          def organize
            organize_then do
              trigger_event(type)
              yield if block_given?
              organize_fields
              report_unused_variables
            end
          end

          # Perform the organization step
          def organize_then(&block)
            super(block) do
              parse_variables(@node[2])
              parse_directives(@node[3], type)
              parse_selection(@node[4])
            end
          end

          # Resolve all the fields
          def resolve
            resolve_then { resolve_fields }
          end

          # Don't stack over response when the operation doesn't have a name
          # TODO: As per spec, when an operation has variables, it should not
          # be stacked
          def stacked_selection?
            name.present? && request.operations.size > 1
          end

          # Name used for debug purposes
          def display_name
            @display_name ||= +"#{type.to_s.titlecase} #{name.presence || '__default__'}"
          end

          # Add an error for each not used variable
          def report_unused_variables
            return if arguments.nil?

            (arguments.keys - used_variables.to_a).each do |key|
              argument = arguments[key]
              request.report_node_error((+<<~MSG).squish, argument.node)
                Variable $#{argument.gql_name} was provided to #{log_source} but not used.
              MSG
            end

            # Report all used variables to the request for greater scope
            request.instance_variable_get(:@used_variables).merge(arguments.keys)

            # Clear anything that is not necessary anymore
            @used_variables = nil
          end

          # If there is another operation with the same name already defined,
          # raise an error. If an anonymous was started, then any other
          # operations is invalid.
          def check_invalid_operation!
            other = request.document[0].find do |other|
              other != @node && name == other[1]
            end

            return if other.nil?
            invalidate!

            if name.nil?
              request.report_node_error((+<<~MSG).squish, self)
                Unable to process the operation #{display_name} when the document
                contain multiple anonymous operations.
              MSG
            else
              request.report_node_error((+<<~MSG).squish, self)
                Duplicated operation named "#{name}" defined on
                line #{other.begin_line}:#{other.begin_column}.
              MSG
            end
          end
      end
    end
  end
end
