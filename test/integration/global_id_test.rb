require 'integration/config'

class Integration_GlobalIDTest < GraphQL::IntegrationTestCase
  load_schema 'memory'

  SCHEMA = ::StartWarsMemSchema

  ## CREATE

  def test_create_directive
    obj = GraphQL::Directive::DeprecatedDirective
    assert_gid_value('gql://base/Directive/deprecated', obj)
  end

  def test_create_directive_instance
    obj = GraphQL::DeprecatedDirective()
    assert_gid_value('gql://base/Directive/deprecated?', obj)

    obj = GraphQL::DeprecatedDirective(reason: 'A B')
    assert_gid_value('gql://base/Directive/deprecated?reason=A+B', obj)
  end

  def test_create_schema
    assert_gid_value('gql://start-wars-mem/Schema', SCHEMA)
  end

  def test_create_query_field
    obj = SCHEMA[:query][:hero]
    assert_gid_value('gql://start-wars-mem/Schema/query/hero', obj)
  end

  def test_create_mutation_field
    obj = SCHEMA[:mutation][:change_human]
    assert_gid_value('gql://start-wars-mem/Schema/mutation/changeHuman', obj)
  end

  def test_create_object_field
    obj = GraphQL::HumanObject[:name]
    assert_gid_value('gql://start-wars-mem/HumanObject/name', obj)
  end

  def test_create_scalar_type
    obj = GraphQL.type_map.fetch(:string)
    assert_gid_value('gql://base/Type/String', obj)
  end

  def assert_gid_value(result, object)
    assert_equal(result, object.to_gid.to_s)
  end

  ## PARSE

  def test_parse_directive
    obj = find_gid('gql://base/Directive/deprecated')
    assert_equal(GraphQL::Directive::DeprecatedDirective, obj)
  end

  def test_parse_directive_instance
    obj = find_gid('gql://base/Directive/deprecated?')
    assert_instance_of(GraphQL::Directive::DeprecatedDirective, obj)
    assert_nil(obj.args[:reason])

    obj = find_gid('gql://base/Directive/deprecated?reason=A+B')
    assert_instance_of(GraphQL::Directive::DeprecatedDirective, obj)
    assert_equal('A B', obj.args[:reason])

    obj = find_gid('gql://base/Directive/skip?if=false')
    assert_instance_of(GraphQL::Directive::SkipDirective, obj)
    assert_equal(false, obj.args[:if])
  end

  def test_parse_schema
    assert_equal(SCHEMA, find_gid('gql://start-wars-mem/Schema'))
  end

  def test_parse_query_field
    obj = find_gid('gql://start-wars-mem/Schema/query/hero')
    assert_equal(SCHEMA[:query][:hero], obj)
  end

  def test_parse_mutation_field
    obj = find_gid('gql://start-wars-mem/Schema/mutation/changeHuman')
    assert_equal(SCHEMA[:mutation][:change_human], obj)
  end

  def test_parse_object_field
    obj = find_gid('gql://start-wars-mem/HumanObject/name')
    assert_equal(GraphQL::HumanObject[:name], obj)
  end

  def test_parse_scalar_type
    obj = find_gid('gql://base/Type/String')
    assert_equal(GraphQL.type_map.fetch(:string), obj)
  end

  def find_gid(gid)
    GraphQL::GlobalID.find(gid)
  end
end
