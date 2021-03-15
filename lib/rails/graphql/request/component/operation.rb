# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
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

          # Helper method to initialize an operation given the data
          def build(request, node, data)
            request.build(const_get(data[:kind].classify), request, node, data)
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

        def initialize(request, node, data)
          @name = data[:name]
          @request = request

          super(node, data)

          check_invalid_operation!
        end

        # The list of fields comes from the +fields_for+ of the same type as
        # the +type+ of the operation
        def fields_source
          schema.fields_for(type)
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

        # Stores all the used arguments to report not used ones
        def used_variables
          @used_variables ||= Set.new
        end

        # A fast way to access the correct display name for log or errors
        def log_source
          @log_source ||= name.blank? ? type : "#{name} #{type}"
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
              parse_variables
              parse_selection
              parse_directives(type)
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
            @display_name ||= "#{type.to_s.titlecase} #{name.presence || '__default__'}"
          end

          # Add an error for each not used variable and then clean up some data
          def report_unused_variables
            (arguments.keys - used_variables.to_a).each do |key|
              argument = arguments[key]
              request.report_node_error(<<~MSG.squish, argument.node || @node)
                Unused variable $#{argument.gql_name} on #{log_source}.
              MSG
            end

            @arguments = nil
            @used_variables = nil
          end

          # If there is another operation with the same name already defined,
          # raise an error. If an anonymous was started, then any other
          # operatios is invalid.
          def check_invalid_operation!
            if request.operations.key?(nil)
              invalidate!

              request.report_node_error(<<~MSG.squish, @node)
                Unable to process the operation #{display_name} when the document
                contain multiple anonymous operations.
              MSG
            elsif request.operations.key?(name)
              invalidate!

              other_node = request.operations[name].instance_variable_get(:@node)
              location = GraphQL::Native.get_location(other_node)

              request.report_node_error(<<~MSG.squish, @node)
                Duplicated operation named "#{name}" defined on
                line #{location.begin_line}:#{location.begin_column}.
              MSG
            end
          end
      end
    end
  end
end
