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
      PRESENCE_VALIDATOR = ::ActiveRecord::Validations::PresenceValidator
      ABSTRACT_REFLECTION = ::ActiveRecord::Reflection::AbstractReflection

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
        build_attribute_fields(self)
        build_reflection_fields(self)
      end

      on :input do
        build_attribute_fields(self)
        build_reflection_inputs(self)
        safe_field(:_delete, Type::Scalar::BooleanScalar)
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
          skip_fields += [primary_key] unless skip_primary_key

          send("#{adapter_key}_attributes", skip_primary_key) do |attribute, *args|
            yield attribute, *args unless skip_fields.include?(attribute)
          end
        end

        # Iterate over all the model reflections
        def each_reflection
          skip_fields = all_skip_fields.map(&:to_s)
          model._reflections.each_value do |reflection|
            next if skip_fields.include?(attribute)

            reflection = model._reflections[reflection.to_s] \
              unless reflection.is_a?(ABSTRACT_REFLECTION)

            yield reflection unless reflection.nil?
          end
        end

        # Returns the input field that a source represents
        def input_field
          input.as_field
        end

        # Before attaching the fields, ensure to load adapter-specific settings
        def attach_fields!
          GraphQL.enable_ar_adapter(adapter_name)
          super
        end

        protected

          # Build all necessary attribute fields into the given +holder+
          def build_attribute_fields(holder)
            each_attribute do |key, type, options|
              options[:null] = required?(key) unless options.key?(:null)
              holder.field(key, type, **options) unless holder.field?(key)
            end
          end

          # Build all necessary reflection fields into the given +holder+
          def build_reflection_fields(holder)
            each_reflection do |item|
              next if holder.field?(item.name)
              Core.type_map.after_register(item.klass, namespaces: namespaces) do |object|
                options = item_to_options(item)

                if object.is_a?(Source::ActiveRecordSource)
                  source_name = item.collection? ? object.plural : object.singular
                  proxy_options = options.merge(alias: reflection.name, of_type: :proxy)
                  field = holder.safe_field(source, **proxy_options) \
                    if (source = object.query_fields[source_name]).present?
                end

                field ||= holder.field(item.name, object, **options)
                field.before_resolve(:load_association, item.name)
              end
            end
          end

          # Build all +accepts_nested_attributes_for+ inside the input object
          def build_reflection_inputs(holder)
            model.nested_attributes_options.each_key do |reflection_name|
              next if (reflection = model._reflect_on_association(reflection_name)).nil?

              expected_name = reflection.klass.name.tr(':', '')
              expected_name += 'Input' unless expected_name.ends_with?('Input')

              Core.type_map.after_register(expected_name, namespaces: namespaces) do |input|
                options = item_to_options(reflection)
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
            return false if User.columns_hash[attr_name]&.default.present?
            return false unless model._validators.key?(attr_name.to_sym)
            model._validators[attr_name.to_sym].any?(PRESENCE_VALIDATOR)
          rescue ::ActiveRecord::StatementInvalid
            false
          end
      end
    end
  end
end
