# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Source
    #
    # Source is an abstract object that can contains fields, objects, and
    # informations that them are delivered to the relative schemas throughout
    # proxies, ensuring that it still kepps the main ownership of the objects
    class Source
      extend ActiveSupport::Autoload
      extend Helpers::InheritedCollection
      extend Helpers::WithSchemaFields
      extend Helpers::WithNamespace

      DEFAULT_NAMESPACES = %i[base].freeze

      eager_autoload do
        autoload :ActiveRecordSource
      end

      class ScopedConfig < Struct.new(:receiver, :self_object) # :nodoc: all
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

      # List of hook namess used while describing a new source. This basically
      # set the order of the execution of the hooks while validating the hooks
      # callbacks using the +on+ method.
      class_attribute :hook_names, instance_writer: false,
        default: %i[object input query mutation subscription].to_set

      # The name of the class to be used as superclass for the generate GraphQL
      # object type of this source
      class_attribute :object_class, instance_writer: false,
        default: '::Rails::GraphQL::Type::Object'

      # The name of the class to be used as superclass for the generate GraphQL
      # input type of this source
      class_attribute :input_class, instance_writer: false,
        default: '::Rails::GraphQL::Type::Input'

      # The list of hooks defined in order to describe a source
      inherited_collection :hooks, instance_reader: false,
        default: (Hash.new { |h, k| h[k] = [] })

      self.abstract = true

      class << self
        attr_reader :schemas

        delegate :field, :proxy_field, :overwrite_field, :[], :field?,
          :field_names, to: :object

        # Get the main name of the source
        def base_name
          @base_name ||= name.demodulize[0..-7]
        end

        # Wait the end of the class in order to create the objects
        def inherited(subclass)
          subclass.abstract = false
          TracePoint.trace(:end) do |tracer|
            next unless tracer.self.eql?(subclass)

            tracer.disable
            subclass.send(:build!) unless subclass.abstract?
          end
        end

        # Get all merged hooks for a given +key+. It overrides the original
        # +all_hooks+ from
        # {InheritedCollection}[rdoc-ref:Rails::GraphQL::Helpers::InheritedCollection]
        # which provides the support for a nil +key+
        def all_hooks(key = nil)
          if key.nil?
            (superclass.try(:all_hooks) || {}).merge(hooks) do |_, l_value, r_value|
              l_value + r_value
            end
          else
            (superclass.try(:all_hooks, key) || []) + hooks[key]
          end
        end

        # Return the GraphQL object type associated with the source. It will
        # create one if it's not defined yet. The created class will be added
        # to the +::GraphQL+ namespace with the addition of any namespace of the
        # currect class
        def object
          @object ||= begin
            klass = Class.new(object_class.constantize)
            klass.add_namespace(*namespaces)

            if respond_to?(:assigned_class, true) && assigned_class.present?
              klass.instance_variable_set(:@assigned_to, assigned_class.name)
              klass.instance_variable_set(:@assigned_class, assigned_class)
            end

            gql_module.const_set("#{base_name}Object", klass)
          end
        end

        # Return the GraphQL input type associated with the source. It will
        # create one if it's not defined yet. The created class will be added
        # to the +::GraphQL+ namespace with the addition of any namespace of the
        # currect class
        def input
          @input ||= begin
            klass = Class.new(input_class.constantize)
            klass.add_namespace(*namespaces)

            if respond_to?(:assigned_class, true) && assigned_class.present?
              klass.instance_variable_set(:@assigned_to, assigned_class.name)
              klass.instance_variable_set(:@assigned_class, assigned_class)
            end

            gql_module.const_set("#{base_name}Input", klass)
          end
        end

        # Check if the object was already built
        def built?
          !!@built
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
                schema.add_proxy(type, field)
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

        protected

          # Add a new description hook. You can use +throw :done+ and skip
          # parent hooks. If the class is already built, then execute the hook.
          # Use the +unshift: true+ to add the hook at the beginning of the
          # list, which will then be the last to run
          def on(hook_name, unshift: false, &block)
            raise ArgumentError, <<~MSG.squish unless hook_names.include?(hook_name.to_sym)
              The #{hook_name.inspect} is not a valid hook method.
            MSG

            if built?
              send("run_#{hook_name}_hooks", block)
            else
              hooks[hook_name.to_sym].public_send(unshift ? :unshift : :push, block)
            end
          end

          # Creates a hook that throws a done action, preventing any parent hooks
          def skip(*names)
            names.each do |hook_name|
              hook_name = hook_name.to_s.singularize.to_sym
              on(hook_name) { throw :done }
            end
          end

          # This is a shortcut to +skip hook_name+ and then
          # +on hook_name do; end+
          def override(hook_name, &block)
            skip(hook_name)
            on(hook_name, &block)
          end

          # It's an alternative to +self.hook_names -= %i[*names]+ which
          # disables a specific hook
          def disable(*names)
            hook_names -= names.map { |hook_name| hook_name.to_s.singularize.to_sym }
          end

          # It's an alternative to +self.hook_names += %i[*names]+ which
          # enables additional hooks
          def enable(*names)
            hook_names += names.map { |hook_name| hook_name.to_s.singularize.to_sym }
          end

        private

          # Return the module where the GraphQL types should be created at
          def gql_module
            module_parents.include?(::GraphQL) ? module_parents.first : ::GraphQL
          end

          # Build all the objects associated with this source
          def build!
            return if built?
            @built = true

            hook_names.each do |hook_name|
              catch(:done) { send("run_#{hook_name}_hooks") }
            end

            attach_fields!
          end

          {
            object:       'object',
            input:        'input',
            query:        format('schema_scoped_config(self, %s)', ':query'),
            mutation:     format('schema_scoped_config(self, %s)', ':mutation'),
            subscription: format('schema_scoped_config(self, %s)', ':subscription'),
          }.each do |key, object|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def run_#{key}_hooks(list = nil)
                source_config = Source::ScopedConfig.new(self, #{object})
                Array.wrap(list.presence || all_hooks(:#{key})).reverse_each do |block|
                  source_config.instance_exec(&block)
                end
              end
            RUBY
          end
      end
    end
  end
end
