# frozen_string_literal: true

module Rails
  module GraphQL
    # All the helper methods for building the source
    module Source::ActiveRecordSource::Builders
      # Override the object class to identify interfaces due to STI
      def object_class
        sti_interface? ? interface_class : super
      end

      # List of all columns that should be threated as IDs
      # TODO: Add a exclusive cache for the build process
      def id_columns
        @id_columns ||= begin
          result = Set.new(GraphQL.enumerate(primary_key))
          each_reflection.each_with_object(result) do |item, arr|
            arr << item.foreign_key.to_s if item.belongs_to?
          end
        end
      end

      # Get all unique attribute names that exists in the current model
      # TODO: Improve this by combining with the above method
      def reflection_attributes(holder)
        result = Set.new(GraphQL.enumerate(primary_key))
        each_reflection(holder).each_with_object(result) do |item, items|
          next unless item.belongs_to?
          items << item.foreign_key.to_s
          items << item.foreign_key if item.polymorphic?
        end
      end

      # Iterate over all the attributes, except the primary key, from the model
      # but already set to be imported to GraphQL fields
      # TODO: Turn into an enumerator
      def each_attribute(holder, skip_primary_key = true)
        adapter_key = GraphQL.ar_adapter_key(adapter_name)

        skip_fields = skips_for(holder)&.map(&:to_s) || Set.new
        skip_fields << model.inheritance_column
        skip_fields << primary_key unless skip_primary_key

        send(:"#{adapter_key}_attributes") do |attribute, *args, **xargs|
          yield(attribute, *args, **xargs) unless skip_fields.include?(attribute)
        end
      end

      # Iterate over all the model reflections
      def each_reflection(holder = nil, &block)
        skip_fields = skips_for(holder)&.map(&:to_s)&.to_set if holder
        model._reflections.each_value.select do |reflection|
          next if skip_fields&.include?(reflection.name.to_s)

          reflection = model._reflections[reflection.to_s] \
            unless reflection.is_a?(abstract_reflection)

          !reflection.nil?
        end.each(&block)
      end

      # Build arguments that correctly reflect the primary key, as a single
      # column or as an array of columns
      def build_primary_key_arguments(holder)
        if primary_key.is_a?(::Array)
          primary_key.each { |key| holder.argument(key, :id, null: false) }
        else
          holder.argument(primary_key, :id, null: false)
        end
      end

      protected

        # Check if the given model is consider an interface due to single table
        # inheritance and the given model is the base class
        def sti_interface?
          @sti_interface ||= begin
            model.has_attribute?(model.inheritance_column) && model.base_class == model
          end
        end

        # Build all enums associated to the class, collecting them from the
        # model setting
        def build_enum_types
          return remove_instance_variable(:@enums) if enums.blank?

          @enums = enums.map do |attribute, setting|
            class_name = base_name + attribute.to_s.classify
            [attribute.to_s, create_enum(class_name, setting, once: true)]
          rescue DuplicatedError
            next
          end.compact.to_h.freeze
        end

        # Build all necessary attribute fields into the given +holder+
        def build_attribute_fields(holder, **field_options)
          attributes_as_ids = reflection_attributes(holder)
          each_attribute(holder) do |key, type, **options|
            next if skip.include?(key) || holder.field?(key)

            str_key = key.to_s
            type = (defined?(@enums) && @enums.key?(str_key) && @enums[str_key]) ||
              (attributes_as_ids.include?(str_key) && :id) || type

            options[:null] = !attr_required?(key) unless options.key?(:null)
            holder.field(key, type, **options.merge(field_options[key] || {}))
          end
        end

        # Build all necessary reflection fields into the given +holder+
        def build_reflection_fields(holder)
          each_reflection(holder) do |item|
            next if holder.field?(item.name)
            type_map_after_register(item.klass) do |type|
              next unless (type.object? && type.try(:assigned_to) != item.klass) ||
                type.interface?

              options = reflection_to_options(item)

              if type <= Source::ActiveRecordSource
                source_name = item.collection? ? type.plural : type.singular
                proxy_options = options.merge(alias: reflection.name, of_type: :proxy)

                if (source = type.query_fields[source_name]).present?
                  field = holder.safe_field(source, **proxy_options)
                end
              end

              if (field ||= holder.safe_field(item.name, type, **options))
                field.before_resolve(:preload_association, item.name)
                field.before_resolve(:build_association_scope, item.name)
                field.resolve(:parent_owned_records, item.collection?)
              end
            end
          end
        end

        # Build all +accepts_nested_attributes_for+ inside the input object
        def build_reflection_inputs(holder)
          model.nested_attributes_options.each_key do |reflection_name|
            next if (reflection = model._reflect_on_association(reflection_name)).nil?

            expected_name = reflection.klass.name.tr(':', '')
            expected_name += 'Input' unless expected_name.end_with?('Input')

            type_map_after_register(expected_name) do |input|
              options = reflection_to_options(reflection).merge(null: true)
              field_name = "#{reflection.name}_attributes"
              holder.safe_field(field_name, input, **options)
            end
          end
        end

        # Transform a replection into a field options
        def reflection_to_options(reflection)
          options = { array: reflection.collection? }

          required = options[:array]
          required ||= attr_required?(reflection.name)
          required ||= attr_required?(reflection.association_foreign_key) \
            if reflection.belongs_to? && !reflection.options[:optional]

          options[:nullable] = !options[:array]
          options[:null] = !required
          options
        end

      private

        def abstract_reflection # :nodoc:
          ::ActiveRecord::Reflection::AbstractReflection
        end
    end
  end
end
