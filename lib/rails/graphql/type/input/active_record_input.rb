# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL Active Record Input
      #
      # The base class for any +ActiveRecord::Base+ class represented as an
      # GraphQL input type
      class Input::ActiveRecordInput < Input::AssignedInput
        self.abstract = true

        # AR Inputs can be owned by a source
        class_attribute :owner, instance_writer: false

        # This is a combination of:
        # * ActiveRecord::Persistence
        # * ActiveRecord::Validations
        # * ActiveRecord::AttributeMethods::Dirty
        delegate :attribute_before_last_save, :attribute_change_to_be_saved,
          :attribute_in_database, :attributes_in_database, :changed_attribute_names_to_save,
          :changes_to_save, :decrement, :decrement!, :delete, :destroy, :destroy!, :destroyed?,
          :has_changes_to_save?, :increment, :increment!, :new_record?, :persisted?, :reload,
          :save, :save!, :saved_change_to_attribute, :saved_change_to_attribute?,
          :saved_changes, :saved_changes?, :toggle, :toggle!, :touch, :update, :update!,
          :update_attribute, :update_column, :update_columns, :valid?,
          :will_save_change_to_attribute?, to: :record

        # Return the instance of the record associated with this field
        def record
          @record || instantiate
        end

        # Instanteate the assigned class with the arguments plus any other
        # necessary +extra+ arguments
        def instantiate(**extra)
          extra.reverse_merge!(args.to_h)
          @record = assigned_class.new(**extra)
        end
      end
    end
  end
end
