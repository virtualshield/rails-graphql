# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Strategy
      #
      # This is the base class for the strategies of resolving a request.
      class Strategy
        extend ActiveSupport::Autoload

        autoload :DynamicInstance

        autoload :SequencedStrategy
        autoload :MultiQueryStrategy
        autoload :CachedStrategy

        # Configurations for the prepare step
        PREPARE_XARGS = { object?: true, reverse?: true }.freeze

        # The priority of the strategy
        class_attribute :priority, instance_accessor: false, default: 1

        delegate :operations, :errors, :response, :schema, to: :request

        attr_reader :listeners, :request, :context, :stage

        class << self
          # Check if the strategy can resolve the given +request+. By default,
          # strategies cannot resolve a request. Override this method with a
          # valid checker.
          def can_resolve?(_)
            false
          end
        end

        def initialize(request)
          @request = request
          @objects_pool = {}
          @listeners = Hash.new { |h, k| h[k] = Set.new }
          add_listeners_from(request)
        end

        # Clear all strategy information
        def clear
          @listeners.clear
          @objects_pool.clear
          @stage = @context = @objects_pool = @data_pool = @listeners = nil
        end

        # Executes the strategy in the normal mode
        def resolve!
          raise NotImplementedError
        end

        # Find a given +type+ and store it on request cache
        def find_type!(type)
          request.nested_cache(:types, type) { schema.find_type!(type) }
        end

        # Find a given +directive+ and store it on request cache
        def find_directive!(directive)
          request.nested_cache(:directives, directive) { schema.find_directive!(directive) }
        end

        # Check if any listener were actually added
        def listeners?
          listeners.any?
        end

        # Check if any object is listening to a given +event_name+
        def listening_to?(event_name)
          listeners? && listeners.key?(event_name.to_sym)
        end

        # When running an stacked operation, make sure that the object was added
        # to the list of the listeners
        def stacked(object, &block)
          request.stacked(object, &block)
        end

        # When a +field+ has a perform step, run it under the context of the
        # prepared value from the data pool
        def perform(field, data = nil)
          context.stacked(data || @data_pool[field]) do
            safe_store_data(field) do
              Event.trigger(:perform, field, self, &field.performer)
            end
          end
        end

        # Execute the prepare step for the given +field+ and execute the given
        # block using context stack
        def prepare(field, &block)
          check_fragment_multiple_prepare!(field)
          value = safe_store_data(field) do
            prepared = request.prepared_data_for(field)
            if prepared.is_a?(PreparedData)
              field.prepared_data!
              prepared.all
            else
              Event.trigger(:prepare, field, self, **PREPARE_XARGS)
            end
          end

          perform(field, value) if field.mutation?

          value = @data_pool[field]
          context.stacked(value, &block) unless value.nil?
        end

        # Resolve a value for a given object, It uses the +args+ to prevent
        # problems with nil values.
        def resolve(field, *args, array: false, decorate: false, &block)
          resolve_data_for(field, args)

          value = args.last
          value = field.decorate(value) if decorate
          context.stacked(value) do |current|
            if !array
              block.call(current)
              field.write_value(current)
            else
              field.write_array(current, &block)
            end
          end
        end

        # Get the resolved data for a given field
        def resolve_data_for(field, args)
          return unless args.size.zero?

          if field.try(:dynamic_resolver?)
            prepared = prepared_data_for(field)
            args << Event.trigger(:resolve, field, self, prepared_data: prepared, &field.resolver)
          elsif field.prepared_data?
            args << prepared_data_for(field)
          else
            data_for(args, field)
          end
        end

        # Check if the given class is in the pool, or add a new instance to the
        # pool, and then set the instance as the current object
        def instance_for(klass)
          @objects_pool[klass] ||= begin
            @objects_pool.each_value.find do |value|
              value.is_a?(klass)
            end || begin
              instance = klass.new
              instance = DynamicInstance.new(instance) unless klass < GraphQL::Schema ||
                klass < GraphQL::Type::Object
              instance
            end
          end
        end

        # Trigger an event using a set of filtered objects from +request.stack+.
        # {+trigger_all+}[rdoc-ref:Rails::GraphQL::Event#trigger_all].
        # The filter is based on the listeners that were collected by the
        # strategy.
        def trigger_event(event_name, **xargs)
          return unless listening_to?(event_name)

          # A simpler attempt to remove select less objects (or even none) by
          # assuming that the first item will work as exclusive and
          # non-exclusive, and the others, only non-exclusive or anything
          # different than a +Callback+
          event_name = event_name.to_sym
          list = listeners[event_name]
          objects = request.stack.select.with_index do |obj, idx|
            next unless list.include?(obj)
            next true if idx == 0

            obj.all_events.try(:[], event_name)&.any? do |ev|
              !(ev.is_a?(Callback) && ev.exclusive?)
            end
          end

          # Now trigger with more for all the selected objects
          Event.trigger(event_name, objects, self, **xargs) if objects.present?
        end

        # Check what kind of event listeners the object have, in order to speed
        # up processing by avoiding unnecessary event instances
        def add_listeners_from(object)
          object.all_listeners&.each do |event_name|
            listeners[event_name] << object
          end

          if request.prepared_data_for?(object)
            listeners[:prepare] << object
          end
        end

        # Store a given resolve +value+ for a given +field+
        def store_data(field, value)
          @data_pool[field] = value
        end

        # Only store a given +value+ for a given +field+ if it is not set yet
        def safe_store_data(field, value = nil)
          value ||= yield if block_given?
          @data_pool[field] ||= value unless value.nil?
        end

        # Get the prepared data for the given +field+, getting ready for
        # resolve, while ensuring to check prepared data on request
        def prepared_data_for(field)
          return @data_pool[field] unless field.prepared_data?

          prepared = request.prepared_data_for(field).next
          prepared unless prepared === PreparedData::NULL
        end

        # Simply run the organize step for compilation
        def compile
          for_each_operation { |op| collect_listeners { op.organize! } }
        end

        # Build the cache object
        def cache_dump
          { class: self.class }
        end

        # Organize from cache data
        def cache_load(data)
          data, operations, fragments = data.values_at(:strategy, :operations, :fragments)

          collect_listeners do
            # Load all operations
            operations = operations.transform_values do |operation|
              request.build_from_cache(operation.delete(:type)).tap do |instance|
                instance.instance_variable_set(:@request, request)
                instance.cache_load(operation)
              end
            end

            # Load all fragments
            fragments = fragments&.transform_values do |fragment|
              request.build_from_cache(Component::Fragment).tap do |instance|
                instance.instance_variable_set(:@request, request)
                instance.cache_load(fragment)
              end
            end
          end

          # Mark itself as already organized
          @organized = true

          # Save operations and fragments into the request
          request.instance_variable_set(:@operations, operations)
          request.instance_variable_set(:@fragments, fragments)
        end

        protected

          # Execute a given block for each defined operation
          def for_each_operation
            operations.each do |key, value|
              operations[key] = Component::Operation.build(request, value) \
                if value.is_a?(::GQLParser::Token)

              yield(operations[key])
            end
          end

          # A start of the organize step
          def collect_listeners
            return if defined?(@organized)
            @stage = :organize
            yield
          end

          # This is where the strategy is most effective. By preparing the tree,
          # it can load data in a pretty smart way
          def collect_data(force = false)
            @stage = :prepare
            @data_pool = {}
            @context = request.build(Request::Context)

            # TODO: Create an orchestrator to allow cross query loading
            yield if force || listening_to?(:prepare)
          end

          # Start collecting results
          def collect_response
            @stage = :resolve
            yield
          end

          # Fetch the data for a given field and set as the first element
          # of the returned list
          def data_for(result, field)
            return result << @data_pool[field] if @data_pool.key?(field)
            return if field.entry_point?

            key = field.method_name
            if (current = context.current_value).is_a?(::Hash)
              result << (current.key?(key) ? current[key] : current[field.gql_name])
            elsif current.respond_to?(key)
              result << current.public_send(key)
            end
          end

          # If the data pool already have data for the given +field+ and there
          # is a fragment in the stack, we throw back to the fragment
          def check_fragment_multiple_prepare!(field)
            return unless @data_pool.key?(field)
            throw(:fragment_prepared) if request.stack.any?(Component::Fragment)
          end
      end
    end
  end
end
