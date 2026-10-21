# frozen_string_literal: true

module Rails
  module GraphQL
    # The params of an input built by an ActiveRecord source leave out every
    # null the model cannot take, so that such a null and a missing value mean
    # the same to the record
    module Source::ActiveRecordSource::InputParams
      def params
        result = super
        model = safe_assigned_class
        return result if model.nil?

        result.reject { |key, value| value.nil? && null_left_out?(model, key.to_s) }
      end

      private

        # A key that is not a column, a column that cannot hold NULL, the
        # primary key, the inheritance column, or the foreign key (and the type
        # column) of a +belongs_to+ the model requires
        def null_left_out?(model, key)
          column = model.columns_hash[key]
          return true if column.nil? || !column.null
          return true if GraphQL.enumerate(model.primary_key).any? { |name| name.to_s == key }
          return true if key == model.inheritance_column.to_s

          model.reflect_on_all_associations(:belongs_to).any? do |reflection|
            required_association?(model, reflection) && association_column?(reflection, key)
          end
        end

        def required_association?(model, reflection)
          optional = reflection.options[:optional]
          optional.nil? ? model.belongs_to_required_by_default : !optional
        end

        def association_column?(reflection, key)
          GraphQL.enumerate(reflection.foreign_key).any? { |name| name.to_s == key } ||
            (reflection.polymorphic? && reflection.foreign_type.to_s == key)
        end
    end
  end
end
