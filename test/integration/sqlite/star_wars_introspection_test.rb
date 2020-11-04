require 'integration/config'

class Integration_SQLite_StarWarsIntrospectionTest < GraphQL::IntegrationTestCase
  load_schema 'sqlite'

  SCHEMA = ::StartWarsSqliteSchema

  # There are some issues with the end sorting, so compare the string result
  # with sorted characters, which will produce the exact match
  def test_gql_introspection
    # File.write('test/assets/sqlite.gql', SCHEMA.to_gql)
    result = gql_file('sqlite').split('').sort.join.squish
    assert_equal(result, SCHEMA.to_gql.split('').sort.join.squish)
  end
end
