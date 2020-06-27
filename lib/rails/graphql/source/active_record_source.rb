# frozen_string_literal: true

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
      extend Helpers::WithAssignment

      validate_assignment(::ActiveRecord::Base) do |value|
        "The \"#{value.name}\" is not a valid Active Record model"
      end

      self.object_class = '::Rails::GraphQL::Type::Object::ActiveRecordObject'
      self.input_class = '::Rails::GraphQL::Type::Input::ActiveRecordInput'
      self.abstract = true

      on :object do
        field(primary_key, :id, null: false)
      end

      on :input do
        field(primary_key, :id)
      end

      on :query do
        field(plural,   object, full: true)
        field(singular, object, null: false) do
          id_argument(primary_key)
        end
      end

      on :mutation do
        base_name = model_name.name

        field("create#{base_name}", object, null: false) do
          argument(param_key, input, null: false)
        end

        field("update#{base_name}", object, null: false) do
          argument(param_key, input, null: false)
          id_argument(primary_key, null: true)
        end

        field("delete#{base_name}", :bool, null: false) do
          id_argument(primary_key)
        end
      end

      class << self
        delegate :primary_key, :model_name, to: :model
        delegate :singular, :plural, :param_key, to: :model_name

        # Allow the assignment to be figured out from the name of class
        def assigned_to
          return super if defined? @assigned_to
          @assigned_to = name.delete_prefix('GraphQL::')[0..-7]
        end

        alias model assigned_class
        alias model= assigned_to=
      end
    end
  end
end
