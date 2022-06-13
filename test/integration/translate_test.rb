require 'integration/config'

class Translate_test < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :translate

    configure do |config|
      config.enable_string_collector = false
    end

    query_fields do
      field(:sample1, :string)
    end

  end

  def test_simple_field
    byebug
    assert_equal("A", SCHEMA[:query][:sample1].description )
  end

  # directive (class)

  # enum
  # argument(field)
  # object
  # input
  # interface
  # union
  ##! scalar()

  # def test_gql_introspection
  #   # File.write('test/assets/translate.gql', SCHEMA.to_gql)
  #   result = gql_file('translate').split('').sort.join.squish
  #   assert_equal(result, SCHEMA.to_gql.split('').sort.join.squish)
  # end
end
