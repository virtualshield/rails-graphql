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
      validate_assignment(::ActiveRecord::Base) do |value|
        "The \"#{value.name}\" is not a valid Active Record model"
      end

      self.object_class = '::Rails::GraphQL::Type::Object::ActiveRecordObject'
      self.input_class = '::Rails::GraphQL::Type::Input::ActiveRecordInput'
      self.abstract = true

      on :enum do
        @enums = enums.map do |attribute, setting|
          [attribute.to_s, create_enum(attribute.to_s, setting)]
        end.to_h.freeze
      end

      on :object do
        safe_field(primary_key, Type::Scalar::IdScalar, null: false)
        build_attribute_inputs(self)
        build_association_fields(self)
      end

      on :input do
        safe_field(primary_key, Type::Scalar::IdScalar)
        build_attribute_inputs(self)
        build_association_inputs(self)
      end

      on :query do
        id_argument = arg(primary_key, Type::Scalar::IdScalar, null: false)

        safe_field(plural,   object, full: true)
        safe_field(singular, object, null: false, arguments: id_argument)
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

        # Stores columns associated with enums so that the fields can have a
        # correctly assigned type
        def enums
          @enums ||= model.defined_enums.dup
        end

        # Iterate over all the attributes, except the primary key, from the
        # model but already set to be imported to GraphQL fields
        def each_attribute(skip_primary_key = true)
          adapter_key = GraphQL.ar_adapter_key(adapter_name)

          skip_fields = all_skip_fields.map(&:to_s)
          skip_fields += [primary_key] if skip_primary_key

          send("#{adapter_key}_attributes", skip_primary_key) do |attribute, *args|
            yield attribute, *args unless skip_fields.include?(attribute)
          end
        end

        # Iterate over all the model reflections
        def each_association
          skip_fields = all_skip_fields.map(&:to_s)
          model._reflections.each_value do |reflection|
            yield reflection unless skip_fields.include?(attribute)
          end
        end

        # Before attaching the fields, ensure to load adapter-specific settings
        def attach_fields!
          GraphQL.enable_ar_adapter(adapter_name)
          super
        end

        protected

          # Build all necessary attribute fields into the given +holder+
          def build_attribute_inputs(holder)
            each_attribute do |key, type, options|
              holder.field(key, type, **options) unless holder.field?(key)
            end
          end

          # Build all necessary association fields into the given +holder+
          def build_association_fields(holder)
            each_association { |reflection| build_reflection_field(holder, reflection) }
          end

          # This is mostly for shareability
          def build_reflection_field(holder, reflection)
            reflection = model._reflections[reflection.to_s] \
              unless reflection.is_a?(ActiveRecord::Reflection::AbstractReflection)

            return if reflection.nil? || holder.field?(reflection.name)

            # If a field is created in here, it means that it is better to
            # replace the current key, instead of keeping the more extensive
            # association field. It returns false when it needs to skip the
            # association field activation
            activator = ->(object) do
              field = fetch_association_field(object, reflection)
              return field if field.owner != self

              holder.fields.store_computed_value(key, field) && false
            end

            options = reflection_to_options(reflection)
            field = holder.association_field(reflection.klass, activator, **options)
            field.before_resolve(:load_association, reflection.name)
          end

          # Build all +accepts_nested_attributes_for+ inside the input object
          def build_association_inputs(holder)
            model.nested_attributes_options.each_key do |reflection_name|
              next if (reflection = model._reflect_on_association(reflection_name)).nil?

              expected_name = reflection.klass.name.tr(':', '')
              expected_name += 'Input' unless expected_name.ends_with?('Input')

              options = reflection_to_options(reflection, proxied: false)
              holder.association_field(expected_name, :as_field, **options)
            end
          end

          # When an association object is built, check if it is possible to
          # fetch an existed field or create one
          def fetch_association_field(object, reflection)
            if object.owner.try(:source?)
              field_name = reflection.collection? \
                ? object.owner.plural \
                : object.owner.singular

              field = object.owner.query_fields[field_name]
              return field if field.present?
            end

            options = reflection_to_options(reflection, proxied: false).merge(owner: self)
            field = Field::OutputField.new(reflection.name, object, **options)
            field.before_resolve(:load_association, reflection.name)
            field
          end

          # Transform a replection into a field options
          def reflection_to_options(reflection, proxied: true)
            options = { array: reflection.collection? }
            options[:alias] = reflection.name if proxied
            options[:nullable] = !options[:array] unless proxied
            required = presence_validator?(reflection.name)

            if !required && reflection.belongs_to?
              column = reflection.association_foreign_key
              required ||= presence_validator?(column) ||
                !reflection.active_record.columns_hash[column].null
            end

            options[:null] = !required
            options
          end

          # Check if a given +attr_name+ is associated with a presence validator
          def presence_validator?(attr_name)
            model._validators[attr_name.to_sym]&.any? do |instance|
              instance.kind === :presence
            end
          end
      end
    end
  end
end
