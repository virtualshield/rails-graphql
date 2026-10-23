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

        # The deepest chain of fragments spreading other fragments an operation
        # may have, counted from the operation (a fragment spread in the
        # operation is level 1)
        MAX_FRAGMENT_NESTING = 64

        # How many fragment spreads an operation may follow, counting a
        # fragment's own spreads once per spread of it
        MAX_FRAGMENT_SPREADS = 10_000

        class << self
          alias type kind

          # Helper method to initialize an operation given the node
          def build(request, node)
            request.build(const_get(node.type.to_s.classify, false), request, node)
          rescue ::NameError
            raise NameError, +%[Unable to initialize "#{node.type}" operation.]
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

        # Allow accessing the fake type from the schema. It's used for
        # inline spreads without a specified type
        def type_klass
          return @type_klass if defined?(@type_klass)
          @type_klass = schema.public_send("#{type}_type")
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

        # Add an empty entry if the operation has a name
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
            value ^ request.fragments[fragment].hash
          end
        end

        # Build the cache object
        def cache_dump
          super.merge(type: self.class)
        end

        # Organize from cache data, which still triggers the event with the
        # +type+ of the operation, and stops there if it raised, the same as
        # the organize step does
        def cache_load(data)
          @node = data[:node]
          @name = @node[1]

          super if organize_from_cache { trigger_event(type) }
        end

        # Check the fragments and the depth of an operation loaded from the
        # cache, once every fragment of the request is loaded as well
        def check_cached_document!
          return if unresolvable?

          organize_from_cache do
            check_fragments!
            check_depth!
          end
        end

        protected

          # Trigger a specific event with the +type+ of the operation
          def organize
            stacked { trigger_event(type) }
            organize_then do
              yield if block_given?
              check_fragments!
              check_depth!
              organize_fields
              report_unused_variables
            end
          end

          # Refuse the operation when the document selects fields deeper than
          # the maximum depth configured for the schema. The depth is read from
          # the document itself, before any field is organized, so it is the
          # same whether the operation is fresh or loaded from the cache
          def check_depth!
            limit = schema.config.max_depth
            return if limit.nil?

            limit = Integer(limit)
            current = depth_of(@node[4], Set.new, request.cache(:fragment_depths))
            return if current <= limit

            refuse!(MaxDepthError, (+<<~MSG).squish)
              Query has depth of #{current}, which exceeds max depth of #{limit}
            MSG
          end

          # Raise the given error for the operation, counting its variables as
          # used, since the document used them even though it is refused
          def refuse!(error, message)
            request.instance_variable_get(:@used_variables).merge(arguments.keys) unless arguments.nil?
            raise error, message
          end

          # The deepest nesting of fields in a list of selection nodes, counting
          # a fragment where it is spread. Each fragment is measured once per
          # request, so the walk is linear in the size of the document, and a
          # fragment cycle is not followed
          def depth_of(nodes, spreading, depths)
            return 0 if nodes.nil?

            nodes.map do |node|
              next 1 + depth_of(node[4], spreading, depths) unless node.of_type?(:spread)
              next depth_of(node[3], spreading, depths) if node[0].nil?

              name = node[0].to_s
              next depths[name] if depths.key?(name)

              fragment = fragment_node(node[0])
              next 0 if fragment.nil? || !spreading.add?(name)

              depths[name] = depth_of(fragment[3], spreading, depths)
              spreading.delete(name)
              depths[name]
            end.max || 0
          end

          # Refuse the operation when a fragment it spreads, directly or through
          # other fragments, spreads itself, which the specification treats as
          # an invalid document, when fragments spread more than
          # MAX_FRAGMENT_NESTING levels deep, or when it follows more than
          # MAX_FRAGMENT_SPREADS fragment spreads. All are read from the
          # document before any spread is organized
          def check_fragments!
            _, spreads = measure_fragments(@node[4], Set.new, request.cache(:fragment_measures))
            refuse!(ExecutionError, (+<<~MSG).squish) if spreads > MAX_FRAGMENT_SPREADS
              Query follows more than #{MAX_FRAGMENT_SPREADS} fragment spreads
            MSG
          end

          # The deepest chain of fragment spreads in a list of selection nodes
          # and the number of fragment spreads followed through them, counting
          # a fragment's own spreads once per spread of it. Each fragment is
          # measured once per request, and the chain through every path to it
          # is checked against the limit
          def measure_fragments(nodes, spreading, measures)
            chain = spreads = 0

            nodes&.each do |node|
              if !node.of_type?(:spread)
                depth, count = measure_fragments(node[4], spreading, measures)
              elsif node[0].nil?
                depth, count = measure_fragments(node[3], spreading, measures)
              else
                name = node[0].to_s
                if spreading.include?(name)
                  via = spreading.to_a.drop_while { |other| other != name }.drop(1)
                  refuse!(ExecutionError, (+<<~MSG).squish)
                    Cannot spread fragment "#{name}" within itself
                    #{"via #{via.map(&:inspect).join(', ')}" if via.present?}
                  MSG
                end

                unless measures.key?(name)
                  fragment = fragment_node(node[0])
                  next if fragment.nil?

                  spreading.add(name)
                  check_fragment_nesting!(spreading.size)
                  depth, count = measure_fragments(fragment[3], spreading, measures)
                  measures[name] = [depth + 1, count + 1]
                  spreading.delete(name)
                end

                depth, count = measures[name]
                check_fragment_nesting!(spreading.size + depth)
              end

              chain = depth if depth > chain
              spreads += count
            end

            [chain, spreads]
          end

          # Refuse the operation when fragments spread deeper than the limit
          def check_fragment_nesting!(levels)
            refuse!(ExecutionError, (+<<~MSG).squish) if levels > MAX_FRAGMENT_NESTING
              Query spreads fragments more than #{MAX_FRAGMENT_NESTING} levels deep
            MSG
          end

          # The document node of the fragment with the given name, which the
          # request holds as a component once a spread has built it
          def fragment_node(name)
            fragment = request.fragments&.[](name)
            fragment.is_a?(Component::Fragment) ? fragment.instance_variable_get(:@node) : fragment
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
          def resolve_then(&block)
            super(block) { resolve_fields }
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
