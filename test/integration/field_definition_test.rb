require 'integration/config'

class Integration_FieldDefinitionTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :field_definition
  end

  def test_field_arguments
    SCHEMA.stub_ivar(:@query_fields, {}) do
      field = SCHEMA.add_query_field(:a, :string, arguments: argument(:a, :string))
      assert_equal(1, field.arguments.size)
      assert_equal(:a, field.arguments.values.first.name)
      assert_equal(field, field.arguments.values.first.owner)
    end

    SCHEMA.stub_ivar(:@query_fields, {}) do
      field = SCHEMA.add_query_field(:a, :string, arguments: argument(:a) & argument(:b))
      assert_equal(2, field.arguments.size)
      assert_equal(:a, field.arguments.values.first.name)
      assert_equal(:b, field.arguments.values.last.name)
    end

    SCHEMA.stub_ivar(:@query_fields, {}) do
      field = SCHEMA.add_query_field(:a, :string, arguments: 'id: ID!')
      assert_equal(1, field.arguments.size)
      assert_equal(:id, field.arguments.values.first.name)
      assert_equal(field, field.arguments.values.first.owner)
      assert_equal(GraphQL::Scalar::IdScalar, field.arguments.values.first.type_klass)
    end

    SCHEMA.stub_ivar(:@query_fields, {}) do
      field = SCHEMA.add_query_field(:a, :string, arguments: 'a: Int = 9, b: String = "Ok"')
      assert_equal(2, field.arguments.size)
      assert_equal(:a, field.arguments.values.first.name)
      assert_equal('Int', field.arguments.values.first.type)
      assert_equal(9, field.arguments.values.first.default)
      assert_equal(:b, field.arguments.values.last.name)
      assert_equal('String', field.arguments.values.last.type)
      assert_equal('Ok', field.arguments.values.last.default)
    end
  end

  def argument(*args, **xargs)
    Rails::GraphQL::Argument.new(*args, owner: nil, **xargs)
  end
end
