require 'integration/config'

class Translate_test < GraphQL::IntegrationTestCase

  class SCHEMA < GraphQL::Schema

    query_fields do
      field :sample_5, :string
      field :sample_6, :string
    end

    namespace :translate

    query_fields do
      field :sample_field, :string,
        arguments: arg(:arg_sample, "Sample")
      field :sample_1, :string
      field :sample_2, :string
      field :sample_3, :string
      field :sample_4, :string
    end

    enum :translate

    interface :translate

    object :translate

    union :translate

    input :translate

    scalar :translate
  end

  def test_simple_translate
    assert_equal("Field", SCHEMA[:query][:sample_field].description )
    assert_equal("Argument", SCHEMA[:query][:sample_field].arguments[:arg_sample].description )
    assert_equal("Enum", GraphQL::TranslateEnum.description )
    assert_equal("Interface", GraphQL::TranslateInterface.description )
    assert_equal("Object", GraphQL::TranslateObject.description )
    assert_equal("Union", GraphQL::TranslateUnion.description )
    assert_equal("Input", GraphQL::TranslateInput.description )
    assert_equal("Scalar", GraphQL::TranslateScalar.description )
  end

  def test_all_levels_translate_fields
    assert_equal("A", SCHEMA[:query][:sample_1].description )
    assert_equal("B", SCHEMA[:query][:sample_2].description )
    assert_equal("C", SCHEMA[:query][:sample_3].description )
    assert_equal("D", SCHEMA[:query][:sample_4].description )
    assert_equal("E", SCHEMA[:query][:sample_5].description )
    assert_equal("F", SCHEMA[:query][:sample_6].description )
  end

  def test_request_translate

  end

# def test_gql_introspection
#   File.write('test/assets/translate.gql', SCHEMA.to_gql)
#   result = gql_file('translate').split('').sort.join.squish
#   assert_equal(result, SCHEMA.to_gql.split('').sort.join.squish)
# end
end
