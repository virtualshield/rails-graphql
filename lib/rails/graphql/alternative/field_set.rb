# frozen_string_literal: true

module Rails
  module GraphQL
    module Alternative
      # = GraphQL Alternative Field Set
      #
      # A simple way to store fields that share some logic with each other
      class FieldSet
        extend Helpers::WithFields

        include Helpers::Instantiable

        self.field_type = Field::OutputField
        self.valid_field_types = Type::Object.valid_field_types

        def self.inspect
          +"#<#{self.class.name} @fields=#{fields.inspect}>"
        end
      end

      # = GraphQL Alternative Mutation Set
      #
      # Same as a +FieldSet+ but for mutation fields
      MutationSet = Class.new(FieldSet)
      MutationSet.field_type = Field::MutationField

      # = GraphQL Alternative Subscription Set
      #
      # Same as a +FieldSet+ but for subscription fields
      SubscriptionSet = Class.new(FieldSet)
      SubscriptionSet.field_type = Field::SubscriptionField
    end
  end
end
