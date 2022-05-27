require 'integration/config'

class Integration_CustomizationTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :customization

    configure do |config|
      config.schema_type_names = {
        query: 'A',
        mutation: 'B',
        subscription: 'C',
      }
    end

    query_fields { field(:one, :string) }
    mutation_fields { field(:two, :string) }
    subscription_fields { field(:three, :string) }
  end

  def test_type_name_for
    assert_equal('A', SCHEMA.type_name_for(:query))
    assert_equal('B', SCHEMA.type_name_for(:mutation))
    assert_equal('C', SCHEMA.type_name_for(:subscription))
  end

  def test_type_map
    assert_equal(SCHEMA.query_type, SCHEMA.find_type('A'))
    assert_equal(SCHEMA.mutation_type, SCHEMA.find_type('B'))
    assert_equal(SCHEMA.subscription_type, SCHEMA.find_type('C'))
  end
end
