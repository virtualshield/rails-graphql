require 'integration/config'

class Translate_test < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :translate

    configure do |config|
      config.enable_string_collector = false
      config.default_response_format = :json
    end

    query_fields do
      field :sample_field, :string
      field :sample_a, :string
      field :sample_b, :string
      field :sample_c, :string
      field :sample_d, :string
      field :sample_e, :string
      field :sample_f, :string
    end

    enum :enum_desc
    interface :interface_desc
    object :object_desc
    union :union_desc
    input :input_desc
    scalar :scalar_desc
  end

  def setup
    super.then { $config.enable_i18n_descriptions = true }
  end

  def teardown
    super.then { $config.enable_i18n_descriptions = false }
  end

  def test_simple_translate
    mod = SCHEMA.const_get(Rails::GraphQL::Type::Creator::NESTED_MODULE)
    assert_equal('Field', SCHEMA[:query][:sample_field].description)
    assert_equal('Enum', mod::EnumDescEnum.description)
    assert_equal('Interface', mod::InterfaceDescInterface.description)
    assert_equal('Object', mod::ObjectDescObject.description)
    assert_equal('Union', mod::UnionDescUnion.description)
    assert_equal('Input', mod::InputDescInput.description)
    assert_equal('Scalar', mod::ScalarDescScalar.description)
  end

  def test_all_levels_translate_fields
    assert_equal('A', SCHEMA[:query][:sample_a].description)
    assert_equal('B', SCHEMA[:query][:sample_b].description)
    assert_equal('C', SCHEMA[:query][:sample_c].description)
    assert_equal('D', SCHEMA[:query][:sample_d].description)
    assert_equal('E', SCHEMA[:query][:sample_e].description)
    assert_equal('F', SCHEMA[:query][:sample_f].description)
  end

  def test_request_translate
    result = { data: { __type: { name: 'InterfaceDesc', description: 'Interface' } } }
    assert_result(result, '{ __type(name: "InterfaceDesc") { name description } }')
  end

  def test_gql_introspection
    result = SCHEMA.to_gql
    expected = gql_file('translate').split('').sort.join.squish

    # File.write('test/assets/translate.gql', result)
    assert_equal(expected, result.split('').sort.join.squish)
  end
end
