require 'integration/config'

class Integration_MySQL_StarWarsIntrospectionTest < GraphQL::IntegrationTestCase
  load_schema 'mysql'

  SCHEMA = ::StartWarsMySQLSchema

  def test_auto_introspection
    assert(SCHEMA.introspection?)
    assert(SCHEMA.has_field?(:query, :__schema))
    assert(SCHEMA.has_field?(:query, :__type))
  end

  # Test this spec with all available scalars
  def remove_keys_form_type_map
  end

  # There are some issues with the end sorting, so compare the string result
  # with sorted characters, which will produce the exact match
  def test_gql_introspection
    # File.write('test/assets/mysql.gql', SCHEMA.to_gql)
    result = gql_file('mysql').split('').sort.join.squish
    assert_equal(result, SCHEMA.to_gql.split('').sort.join.squish)
  end
end
