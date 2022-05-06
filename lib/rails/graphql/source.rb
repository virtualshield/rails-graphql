# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Source
    #
    # Source is an abstract object that can contains fields, objects, and
    # informations that them are delivered to the relative schemas throughout
    # proxies, ensuring that it still kepps the main ownership of the objects
    class Source
      extend ActiveSupport::Autoload

      extend Helpers::InheritedCollection
      extend Helpers::WithSchemaFields
      extend Helpers::WithAssignment
      extend Helpers::WithNamespace
      extend Helpers::WithEvents
      extend Helpers::WithCallbacks

      DEFAULT_NAMESPACES = %i[base].freeze

      eager_autoload do
        autoload :ScopedArguments

        autoload :ActiveRecordSource
      end

      # Helper class to be used as the +self+ in configuration blocks
      ScopedConfig = Struct.new(:receiver, :self_object) do
        def respond_to_missing?(method_name, include_private = false)
          self_object.respond_to?(method_name, include_private) ||
            receiver.respond_to?(method_name, include_private)
        end

        def method_missing(method_name, *args, **xargs, &block)
          self_object.respond_to?(method_name, true) \
            ? self_object.send(method_name, *args, **xargs, &block) \
            : receiver.send(method_name, *args, **xargs, &block)
        end
      end

      # If a source is marked as abstract, it means that it generates a new
      # source describer and any non-abstract class inherited from it will be
      # described by this new abstraction
      class_attribute :abstract, instance_writer: false, default: false

      # List of hook names used while describing a new source. This basically
      # set the order of the execution of the hooks while validating the hooks
      # callbacks using the +on+ method. Make sure to kepp the +finish+ hook
      # always at the end of the list
      class_attribute :hook_names, instance_writer: false,
        default: %i[start object input query mutation finish].to_set

      # The list of hooks defined in order to describe a source
      inherited_collection :hooks, instance_reader: false, type: :hash_array

      # The name of the class (or the class itself) to be used as superclass for
      # the generate GraphQL object type of this source
      class_attribute :object_class, instance_writer: false,
        default: '::Rails::GraphQL::Type::Object'

      # The name of the class (or the class itself) to be used as superclass for
      # the generate GraphQL input type of this source
      class_attribute :input_class, instance_writer: false,
        default: '::Rails::GraphQL::Type::Input'

      # Mark if the objects created from this source will build fields for
      # associations associated to the object
      class_attribute :with_associations, instance_writer: false, default: true

      # A list of fields to skip when performing shared methods
      inherited_collection :skip_fields, instance_reader: false

      # A list of fields to skip but segmented by holder source
      inherited_collection :segmented_skip_fields, instance_reader: false, type: :hash_set

      # The purpose of instantiating a source is to have access to its public
      # methods. It then runs from the strategy perspective, pointing out any
      # other methods to the manually set event
      delegate_missing_to :event
      attr_reader :event

      self.abstract = true

      class << self
        attr_reader :schemas

        delegate :field, :proxy_field, :overwrite_field, :field?, :field_names,
          :gql_name, to: :object

        def kind
          :source
        end

        # Sources are close related to objects, meaning that they are type based
        def base_type_class
          :Type
        end

        # Get the main name of the source
        def base_name
          name.demodulize[0..-7] unless abstract?
        end

        # Wait the end of the class in order to create the objects
        def inherited(subclass)
          subclass.abstract = false
          super if defined? super

          pending[subclass] ||= caller(1).find do |item|
            !item.end_with?("`inherited'")
          end
        end

        # Find a source for a given object. If none is found, then raise an
        # exception
        def find_for!(object)
          find_for(object) || raise(::ArgumentError, <<~MSG.squish)
            Unable to find a source for "#{object.name}".
          MSG
        end

        # Using the list of +base_sources+, find the first one that can handle
        # the given +object+
        def find_for(object)
          object = object.constantize if object.is_a?(String)
          base_sources.reverse_each.find { |source| object <= source.assigned_class }
        end

        # Return the GraphQL object type associated with the source. It will
        # create one if it's not defined yet. The created class will be added
        # to the +::GraphQL+ namespace with the addition of any namespace of the
        # currect class
        def object
          @object ||= create_type(superclass: object_class)
        end

        # Return the GraphQL input type associated with the source. It will
        # create one if it's not defined yet. The created class will be added
        # to the +::GraphQL+ namespace with the addition of any namespace of the
        # currect class
        def input
          @input ||= create_type(superclass: input_class)
        end

        # Check if the object was already built
        def built?
          defined?(@built) && !!@built
        end

        # Checks if a given method can act as resolver
        def gql_resolver?(method_name)
          (instance_methods - GraphQL::Source.instance_methods).include?(method_name)
        end

        # Attach all defined schema fields into the schemas using the namespaces
        # configured for the source
        def attach_fields!
          refresh_schemas!
          schemas.each_value do |schema|
            Helpers::WithSchemaFields::SCHEMA_FIELD_TYPES.keys.each do |type|
              list = public_send("#{type}_fields")
              next if list.empty?

              list.each_value do |field|
                next if schema.has_field?(type, field)
                schema.add_proxy_field(type, field)
              end
            end
          end
        end

        # Find all the schemas associated with the configured namespaces
        def refresh_schemas!
          @schemas = (namespaces.presence || DEFAULT_NAMESPACES).map do |ns|
            (schema = Schema.find(ns)).present? ? [ns, schema] : nil
          end.compact.to_h
        end

        def eager_load!
          super

          build_pending!
        end

        protected

          # Find a given +type+ on the same namespaces of the source. It will
          # raise an exception if the +type+ can not be found
          def find_type!(type, **xargs)
            xargs[:base_class] = :Type
            xargs[:namespaces] = namespaces
            GraphQL.type_map.fetch!(type, **xargs)
          end

          # A little bypass to the actual type map after register method which
          # just add the namesapace by default
          # See {TypeMap#after_register}[rdoc-ref:Rails::GraphQL::TypeMap#after_register]
          def type_map_after_register(*args, **xargs, &block)
            xargs[:namespaces] ||= namespaces
            GraphQL.type_map.after_register(*args, **xargs, &block)
          end

          # A helper method to create an enum type
          def create_enum(enum_name, values, **xargs, &block)
            enumerator = values.each_pair if values.respond_to?(:each_pair)
            enumerator ||= values.each.with_index

            xargs = xargs.reverse_merge(once: true)
            create_type(:enum, as: enum_name.classify, **xargs) do
              indexed! if enumerator.first.last.is_a?(Numeric)
              enumerator.sort_by(&:last).map(&:first).each(&method(:add))
              instance_exec(&block) if block.present?
            end
          end

          # Helper method to create a class based on the given +type+ and allows
          # several other settings to be executed on it
          def create_type(type = nil, **xargs, &block)
            name = "#{gql_module.name}::#{xargs.delete(:as) || base_name}"
            superclass = xargs.delete(:superclass)
            with_owner = xargs.delete(:with_owner)

            if superclass.nil?
              superclass = type.to_s.classify
            elsif superclass.is_a?(String)
              superclass = superclass.constantize
            end

            # binding.pry if with_owner

            source = self
            Schema.send(:create_type, name, superclass, **xargs) do
              include Helpers::WithOwner if with_owner
              set_namespaces(*source.namespaces)

              self.owner = source if respond_to?(:owner=)
              self.assigned_to = source.safe_assigned_class \
                if source.assigned? && is_a?(Helpers::WithAssignment)

              instance_exec(&block) if block.present?
            end
          end

          # Add fields to be skipped on the given +source+ as the segment
          def skip_from(source, *fields)
            segmented_skip_fields[source] += fields.flatten.compact.map(&:to_sym).to_set
          end

          # Add a new description hook. You can use +throw :skip+ and skip
          # parent hooks. If the class is already built, then execute the hook.
          # Use the +unshift: true+ to add the hook at the beginning of the
          # list, which will then be the last to run
          def step(hook_name, unshift: false, &block)
            raise ArgumentError, <<~MSG.squish unless hook_names.include?(hook_name.to_sym)
              The #{hook_name.inspect} is not a valid hook method.
            MSG

            if built?
              catch(:skip) { send("run_#{hook_name}_hooks", block) }
            else
              hooks[hook_name.to_sym].public_send(unshift ? :unshift : :push, block)
            end
          end

          # Creates a hook that throws a done action, preventing any parent hooks
          def skip(*names)
            names.each do |hook_name|
              hook_name = hook_name.to_s.singularize.to_sym
              step(hook_name) { throw :skip }
            end
          end

          # This is a shortcut to +skip hook_name+ and then
          # +on hook_name do; end+
          def override(hook_name, &block)
            skip(hook_name)
            step(hook_name, &block)
          end

          # It's an alternative to +self.hook_names -= %i[*names]+ which
          # disables a specific hook
          def disable(*names)
            self.hook_names -= names.flatten.map do |hook_name|
              hook_name.to_s.singularize.to_sym
            end
          end

          # It's an alternative to +self.hook_names += %i[*names]+ which
          # enables additional hooks
          def enable(*names)
            self.hook_names += names.flatten.map do |hook_name|
              hook_name.to_s.singularize.to_sym
            end
          end

          # Return the module where the GraphQL types should be created at
          def gql_module
            name.starts_with?('GraphQL::') ? module_parent : ::GraphQL
          end

          # Get the list of fields to be skipped from the given +holder+ as the
          # segment source
          def skips_for(holder)
            segment = holder.kind
            segment = :input if segment.eql?(:input_object)
            segmented = all_segmented_skip_fields[segment]
            segmented.present? ? all_skip_fields + segmented : all_skip_fields
          end

        private

          # The list of pending sources to be built asscoaited to where they
          # were defined
          def pending
            @@pending ||= {}
          end

          # Check if there are pending sources to be built
          def pending?
            pending.any?
          end

          # Build the pending sources
          def build_pending!
            while (klass, = pending.shift)
              klass.send(:build!) unless klass.abstract?
            end
          end

          # Find all classes that inherits from source that are abstract,
          # meaning that they are a base sources
          def base_sources
            @@base_sources ||= begin
              eager_load!
              descendants.select(&:abstract?).to_set
            end
          end

          # Build all the objects associated with this source
          def build!
            return if built?

            raise DefinitionError, <<~MSG.squish if abstract
              Abstract source #{name} cannot be built.
            MSG

            @built = true

            catch(:done) do
              hook_names.each do |hook_name|
                break if hook_name === :finish
                catch(:skip) { send("run_#{hook_name}_hooks") }
              end
            end

            catch(:skip) { send(:run_finish_hooks) } if respond_to?(:run_finish_hooks, true)
          end

          {
            start:        'self',
            finish:       'self',
            object:       'Helpers::AttributeDelegator.new(self, :object)',
            input:        'Helpers::AttributeDelegator.new(self, :input)',
            query:        format('schema_scoped_config(self, %s)', ':query'),
            mutation:     format('schema_scoped_config(self, %s)', ':mutation'),
            subscription: format('schema_scoped_config(self, %s)', ':subscription'),
          }.each do |key, object|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def run_#{key}_hooks(list = nil)
                source_config = Source::ScopedConfig.new(self, #{object})
                Array.wrap(list.presence || all_hooks[:#{key}]).reverse_each do |block|
                  source_config.instance_exec(&block)
                end
              end
            RUBY
          end
      end
    end
  end
end
