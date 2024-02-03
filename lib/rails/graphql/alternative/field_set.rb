# frozen_string_literal: true

module Rails
  module GraphQL
    module Alternative
      # = GraphQL Alternative Field Set
      #
      # A simple way to store fields that share some logic with each other
      class FieldSet
        extend Helpers::WithNamespace
        extend Helpers::WithFields

        include Helpers::Instantiable

        self.field_type = GraphQL::Field::OutputField
        self.valid_field_types = Type::Object.valid_field_types

        def self.i18n_scope
          :query
        end

        def self.inspect
          +"#<#{self.class.name} @fields=#{fields.inspect}>"
        end
      end

      # = GraphQL Alternative Query Set
      #
      # Exact the same as a +FieldSet+
      QuerySet = FieldSet

      # = GraphQL Alternative Mutation Set
      #
      # Same as a +FieldSet+ but for mutation fields
      MutationSet = Class.new(FieldSet)
      MutationSet.field_type = GraphQL::Field::MutationField
      MutationSet.redefine_singleton_method(:i18n_scope) { :mutation }


      # = GraphQL Alternative Subscription Set
      #
      # Same as a +FieldSet+ but for subscription fields
      SubscriptionSet = Class.new(FieldSet)
      SubscriptionSet.field_type = GraphQL::Field::SubscriptionField
      SubscriptionSet.redefine_singleton_method(:i18n_scope) { :subscription }
    end
  end
end
