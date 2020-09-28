# frozen_string_literal: true

require 'active_record'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Source Active Record
    #
    # This source allows the translation of active record objects into a new
    # source object, creating:
    # 1. 1 Object
    # 2. 1 Input
    # 3. 2 Query fields (ingular and plural)
    # 4. 3 Mutation fields (create, update, destroy)
    class Source::ActiveRecordSource < Source
      include Source::ScopedArguments

      PRESENCE_VALIDATOR = ::ActiveRecord::Validations::PresenceValidator
      ABSTRACT_REFLECTION = ::ActiveRecord::Reflection::AbstractReflection

      validate_assignment(::ActiveRecord::Base) do |value|
        "The \"#{value.name}\" is not a valid Active Record model"
      end

      self.input_class = '::Rails::GraphQL::Type::Input::ActiveRecordInput'
      self.abstract = true

      delegate :primary_key, :singular, :plural, :model, to: :class

      skip_on :input, :created_at, :updated_at

      on :start do
        GraphQL.enable_ar_adapter(adapter_name)
        @enums = enums.map do |attribute, setting|
          [attribute.to_s, create_enum(attribute.to_s, setting, once: true)]
        rescue DuplicatedError
          next
        end.compact.to_h.freeze
      end

      on :object do
        build_attribute_fields(self)
        build_reflection_fields(self)
      end

      on :input do
        extra = { primary_key => { null: true } }
        build_attribute_fields(self, **extra)
        build_reflection_inputs(self)

        safe_field(model.inheritance_column, :string, null: false) if object.interface?
        safe_field(:_delete, :boolean, default: false)

        reference = model.new
        model.columns_hash.each_value do |column|
          change_field(column.name, default: reference[column.name]) \
            if column.default.present? && field?(column.name)
        end
      end

      on :query do
        safe_field(plural, object, full: true) do
          before_resolve :load_records
        end

        safe_field(singular, object, null: false) do
          argument primary_key, :id, null: false
          before_resolve :load_record
        end
      end

      on :mutation do
        safe_field("create_#{singular}", object, null: false) do
          argument singular, input, null: false
          perform :create_record
        end

        safe_field("update_#{singular}", object, null: false) do
          argument primary_key, :id, null: false
          argument singular, input, null: false
          before_resolve :load_record
          perform :update_record
        end

        safe_field("delete_#{singular}", :boolean, null: false) do
          argument primary_key, :id, null: false
          before_resolve :load_record
          perform :destroy_record
        end
      end

      on :finish do
        attach_fields!
        attach_scoped_arguments_to(object.fields)
        attach_scoped_arguments_to(mutation_fields)

        next if model.base_class == model

        # TODO: Allow nested inheritance for setting up implementation
        type_map_after_register(model.base_class.name) do |type|
          object.implements(type) if type.interface?
        end
      end

      class << self
        delegate :primary_key, :model_name, to: :model
        delegate :singular, :plural, :param_key, to: :model_name
        delegate :adapter_name, to: 'model.connection'

        # Allow the assignment to be figured out from the name of class
        def assigned_to
          return super if defined? @assigned_to
          @assigned_to = name.delete_prefix('GraphQL::')[0..-7]
        end

        alias model assigned_class
        alias model= assigned_to=

        # Override the object class to identify interfaces due to STI
        def object_class
          if sti_interface?
            '::Rails::GraphQL::Type::Interface'
          else
            '::Rails::GraphQL::Type::Object::ActiveRecordObject'
          end
        end

        # Stores columns associated with enums so that the fields can have a
        # correctly assigned type
        def enums
          @enums ||= model.defined_enums.dup
        end

        # Iterate over all the attributes, except the primary key, from the
        # model but already set to be imported to GraphQL fields
        def each_attribute(holder, skip_primary_key = true)
          adapter_key = GraphQL.ar_adapter_key(adapter_name)

          skip_fields = skips_for(holder).map(&:to_s)
          skip_fields << model.inheritance_column
          skip_fields << primary_key unless skip_primary_key

          send("#{adapter_key}_attributes") do |attribute, *args|
            yield attribute, *args unless skip_fields.include?(attribute)
          end
        end

        # Iterate over all the model reflections
        def each_reflection(holder)
          skip_fields = skips_for(holder).map(&:to_s)
          model._reflections.each_value do |reflection|
            next if skip_fields.include?(reflection.name.to_s)

            reflection = model._reflections[reflection.to_s] \
              unless reflection.is_a?(ABSTRACT_REFLECTION)

            yield reflection unless reflection.nil?
          end
        end

        protected

          # Check if the given model is consider an interface due to single
          # table inheritance and the given model is the base class
          def sti_interface?
            @sti_interface ||= begin
              model.has_attribute?(model.inheritance_column) && model.base_class == model
            end
          end

          # Build all necessary attribute fields into the given +holder+
          def build_attribute_fields(holder, **field_options)
            each_attribute(holder) do |key, type, options|
              next if skip.include?(key)

              type = @enums[key.to_s] if @enums.key?(key.to_s)
              next if holder.field?(key)

              options[:null] = !required?(key) unless options.key?(:null)
              holder.field(key, type, **options.merge(field_options[key] || {}))
            end
          end

          # Build all necessary reflection fields into the given +holder+
          def build_reflection_fields(holder)
            each_reflection(holder) do |item|
              next if holder.field?(item.name)
              type_map_after_register(item.klass.name) do |type|
                next unless (type.object? && type.try(:assigned_to) != item.klass) ||
                  type.interface?

                options = reflection_to_options(item)

                if type <= Source::ActiveRecordSource
                  source_name = item.collection? ? type.plural : type.singular
                  proxy_options = options.merge(alias: reflection.name, of_type: :proxy)
                  field = holder.safe_field(source, **proxy_options) \
                    if (source = type.query_fields[source_name]).present?
                end

                field ||= holder.field(item.name, type, **options)
                field.before_resolve(:preload_association, item.name)
                field.before_resolve(:build_association_scope, item.name)
                field.resolve(:parent_owned_records)
              end
            end
          end

          # Build all +accepts_nested_attributes_for+ inside the input object
          def build_reflection_inputs(holder)
            model.nested_attributes_options.each_key do |reflection_name|
              next if (reflection = model._reflect_on_association(reflection_name)).nil?

              expected_name = reflection.klass.name.tr(':', '')
              expected_name += 'Input' unless expected_name.ends_with?('Input')

              type_map_after_register(expected_name) do |input|
                options = reflection_to_options(reflection)
                options.merge!(alias: "#{reflection.name}_attributes")
                holder.safe_field(reflection.name, input, **options)
              end
            end
          end

          # Transform a replection into a field options
          def reflection_to_options(reflection)
            options = { array: reflection.collection? }

            required = options[:array]
            required ||= presence_validator?(reflection.name)
            required ||= presence_validator?(reflection.association_foreign_key) \
              if reflection.belongs_to?

            options[:nullable] = !options[:array]
            options[:null] = !required
            options
          end

          # Check if a given +attr_name+ is associated with a presence validator
          # but ignores when there is a default value
          def required?(attr_name)
            return true if attr_name.eql?(primary_key)
            return false if model.columns_hash[attr_name]&.default.present?
            return false unless model._validators.key?(attr_name.to_sym)
            model._validators[attr_name.to_sym].any?(PRESENCE_VALIDATOR)
          rescue ::ActiveRecord::StatementInvalid
            false
          end
      end

      # Prepare to load multiple records from the underlying table
      def load_records
        inject_scopes(model.all, :relation)
      end

      # Prepare to load a single record from the underlying table
      def load_record
        load_records.find(event.argument(primary_key))
      end

      # Get the chain result and preload the records with thre resulting scope
      def preload_association(association, scope = nil)
        event.stop(preload(association, scope || event.last_result), layer: :object)
      end

      # Collect a scope for filters applied to a given association
      def build_association_scope(association)
        scope = model._reflect_on_association(association).klass.unscoped

        # Apply proxied injected scopes
        proxied = event.field.try(:proxied_owner)
        scope = event.on_instance(proxied) do |instance|
          instance.inject_scopes(scope, :relation)
        end if proxied.present? && proxied <= Source::ActiveRecordSource

        # Apply self defined injected scopes
        inject_scopes(scope, :relation)
      end

      # Once the records are pre-loaded due to +preload_association+, use the
      # parent value and the preloader result to get the records
      def parent_owned_records
        records = event.data[:prepared]
        return [] if records.empty?

        records#.records_by_owner[current_value.itself]
      end

      # The perform step for the +create+ based mutation
      def create_record
        input_argument.record.tap(&:save!)
      end

      # The perform step for the +update+ based mutation
      def update_record
        current_value.tap { |record| record.update!(**input_attributes) }
      end

      # The perform step for the +delete+ based mutation
      def destroy_record
        !!current_value.destroy!
      end

      protected

        # Basically get the argument associated to the input
        def input_argument
          event.argument(singular)
        end

        # Get the input argument and return it as model attributes
        def input_attributes
          input_argument.args.to_h
        end

        # Preload the records for a given +association+ using the current value.
        # It can be further specified with a given +scope+
        def preload(association, scope = nil)
          reflection = model._reflect_on_association(association)
          records = Array.wrap(current_value.itself).compact # Loose the dynamic reference
          ar_preloader.send(:preloaders_for_reflection, reflection, records, scope).first
        end

        # Get the cached instance of active record prelaoder
        def ar_preloader
          event.request.cache(:ar_preloader) { ::ActiveRecord::Associations::Preloader.new }
        end
    end
  end
end
