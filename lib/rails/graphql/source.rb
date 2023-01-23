# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Source
    #
    # Source is an abstract object that can contains fields, objects, and
    # information that them are delivered to the relative schemas throughout
    # proxies, ensuring that it still keeps the main ownership of the objects
    class Source
      extend ActiveSupport::Autoload

      extend Helpers::InheritedCollection
      extend Helpers::WithNamespace
      extend Helpers::WithEvents
      extend Helpers::WithCallbacks

      include Helpers::Instantiable

      ATTACH_FIELDS_STEP = -> do
        if fields?
          attach_fields!(type, fields)
          attach_scoped_arguments_to(fields.values)
        end
      end

      autoload :Base
      autoload :Builder

      autoload :ScopedArguments
      autoload :ActiveRecordSource

      extend Source::Builder

      # Helper class to be used as the +self+ in configuration blocks
      ScopedConfig = Struct.new(:receiver, :self_object, :type) do
        def safe_field(name, *args, **xargs, &block)
          return if receiver.send(:skip_field?, name, on: type)
          self_object.safe_field(name, *args, **xargs, &block)
        end

        # skip_field?(item.name, on: holder.kind)
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
      class_attribute :abstract, instance_accessor: false, default: false

      # List of hook names used while describing a new source. This basically
      # set the order of the execution of the hooks while validating the hooks
      # callbacks using the +on+ method
      class_attribute :hook_names, instance_accessor: false,
        default: %i[start object input query mutation subscription].to_set

      # The list of hooks defined in order to describe a source
      inherited_collection :hooks, instance_reader: false, type: :hash_array

      # A list of fields to skip when performing shared methods
      inherited_collection :skip_fields, instance_reader: false, type: :set

      # A list of fields to skip but segmented by holder source
      inherited_collection :segmented_skip_fields, instance_reader: false, type: :hash_set

      # A list of fields that should only be included. Available only when using
      # individual builders
      inherited_collection :segmented_only_fields, instance_reader: false, type: :hash_set

      self.abstract = true

      class << self
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
          name.demodulize[0..-7]
        end

        # :singleton-method:
        # Find a source for a given object. If none is found, then raise an
        # exception
        def find_for!(object)
          find_for(object) || raise(::ArgumentError, (+<<~MSG).squish)
            Unable to find a source for "#{object.name}".
          MSG
        end

        # :singleton-method:
        # Using the list of +base_sources+, find the first one that can handle
        # the given +object+
        def find_for(object)
          object = object.constantize if object.is_a?(String)
          base_sources.reverse_each.find { |source| object <= source.assigned_class }
        end

        # Attach all defined schema fields into the schemas using the namespaces
        # configured for the source
        def attach_fields!(type = :all, from = self)
          schemas.each { |schema| schema.import_into(type, from) }
        end

        # Find all the schemas associated with the configured namespaces
        def schemas
          GraphQL.enumerate(namespaces.presence || :base).lazy.filter_map do |ns|
            Schema.find(ns)
          end
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
          # just add the namespace by default
          # See {TypeMap#after_register}[rdoc-ref:Rails::GraphQL::TypeMap#after_register]
          def type_map_after_register(*args, **xargs, &block)
            xargs[:namespaces] ||= namespaces
            GraphQL.type_map.after_register(*args, **xargs, &block)
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
            raise ArgumentError, (+<<~MSG).squish unless hook_names.include?(hook_name.to_sym)
              The #{hook_name.inspect} is not a valid hook method.
            MSG

            if built?(hook_name)
              hook_scope_for(hook_name).instance_exec(&block)
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
            name.start_with?('GraphQL::') ? module_parent : ::GraphQL
          end

          # Add one or more fields to the list of fields that needs to be
          # ignored in all places. It converts strings to underscore
          def skip_fields!(*list)
            list = list.flatten.map do |value|
              value.is_a?(Symbol) ? value.to_s : value.to_s.underscore
            end

            self.skip_fields.merge(list)
          end

          # Check if a given field +name+ should be skipped on the give type
          def skip_field?(name, on:)
            on = :input if on == :input_object
            name = name.to_s.underscore

            all_skip_fields&.include?(name) ||
              all_segmented_skip_fields.try(:[], on)&.include?(name) ||
              all_segmented_only_fields.try(:[], on)&.exclude?(name)
          end

          # Run a list of hooks using the +source+ as the instance of the block
          def run_hooks(hook_name, source = self)
            all_hooks.try(:[], hook_name.to_sym)&.reverse_each do |block|
              source.instance_exec(&block)
            end
          end

        private

          # Make sure to reset the value of +abstract+
          def inherited(subclass)
            subclass.abstract = false
            super if defined? super
          end

          # Find all classes that inherits from source that are abstract,
          # meaning that they are a base sources
          def base_sources
            @@base_sources ||= GraphQL.config.sources.map(&:constantize).to_set
          end

      end

      step(:query, &ATTACH_FIELDS_STEP)
      step(:mutation, &ATTACH_FIELDS_STEP)
      step(:subscription, &ATTACH_FIELDS_STEP)
    end
  end
end
