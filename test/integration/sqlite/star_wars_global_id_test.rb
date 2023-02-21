require 'integration/config'

class Integration_SQLite_StarWarsGlobalIDTest < GraphQL::IntegrationTestCase
  load_schema 'sqlite'

  SCHEMA = ::StartWarsSqliteSchema

  ## CREATE

  def test_create_query_field
    obj = source[:query][:lite_factions]
    assert_gid_value('gql://star-wars-sqlite/Schema/query/liteFactions', obj)
  end

  def test_create_object
    obj = source.object
    assert_gid_value('gql://star-wars-sqlite/Type/LiteFaction', obj)
  end

  def test_create_input
    obj = source.input
    assert_gid_value('gql://star-wars-sqlite/Type/LiteFactionInput', obj)

    obj = source.input.deserialize(nil)
    assert_gid_value('gql://star-wars-sqlite/Type/LiteFactionInput?', obj)

    params = { name: 'Sample' }
    obj = source.input.deserialize(params)
    assert_gid_value('gql://star-wars-sqlite/Type/LiteFactionInput?name=Sample', obj)

    params = { name: 'Sample', bases_attributes: [{ name: 'Other' }] }
    obj = source.input.deserialize(params)
    assert_gid_value('gql://star-wars-sqlite/Type/LiteFactionInput?basesAttributes[][name]=Other&name=Sample', obj)
  end

  def test_create_object_field
    obj = source.object[:name]
    assert_gid_value('gql://star-wars-sqlite/LiteFaction/name', obj)
  end

  def assert_gid_value(result, object)
    assert_equal(result.gsub(/\[|\]/, { '[' => '%5B', ']' => '%5D' }), object.to_gid.to_s)
  end

  ## PARSE

  def test_parse_query_field
    obj = find_gid('gql://star-wars-sqlite/Schema/query/liteFactions')
    assert_equal(source[:query][:lite_factions], obj.proxied_field)
  end

  def test_parse_object
    obj = find_gid('gql://star-wars-sqlite/Type/LiteFaction')
    assert_equal(source.object, obj)
  end

  def test_parse_input
    obj = find_gid('gql://star-wars-sqlite/Type/LiteFactionInput')
    assert_equal(source.input, obj)

    obj = find_gid('gql://star-wars-sqlite/Type/LiteFactionInput?')
    assert_instance_of(source.input, obj)
    assert_empty(obj.params)

    obj = find_gid('gql://star-wars-sqlite/Type/LiteFactionInput?name=Sample')
    assert_instance_of(source.input, obj)
    assert_equal('Sample', obj.params[:name])

    obj = find_gid('gql://star-wars-sqlite/Type/LiteFactionInput?bases_attributes[][name]=Other&name=Sample')
    assert_instance_of(source.input, obj)
    assert_equal([{name: 'Other'}], obj.params[:bases_attributes])
    assert_equal('Sample', obj.params[:name])
  end

  def test_parse_object_field
    obj = find_gid('gql://star-wars-sqlite/LiteFaction/name')
    assert_equal(source.object[:name], obj)
  end

  protected

    def find_gid(gid)
      GraphQL::GlobalID.find(gid)
    end

    def source
      StartWarsSqliteSchema.const_get(:NestedTypes)::LiteFactionSource
    end
end
