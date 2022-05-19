require 'integration/config'

class Integration_CustomizationTest < GraphQL::IntegrationTestCase

  class SCHEMA < GraphQL::Schema
    namespace :customization
  end

  def test_type_name_for
    $config = Rails::GraphQL.config
    $config.schema_type_names = {
      query: '_QueryTest',
      mutation: '_MutationTest',
      subscription: '_SubscriptionTest',
    }
    assert_equal(SCHEMA.type_name_for(:query), "_QueryTest")
    assert_equal(SCHEMA.type_name_for(:mutation), "_MutationTest")
    assert_equal(SCHEMA.type_name_for(:subscription), "_SubscriptionTest")
  end

  $config.schema_type_names = {
    query: '_Query',
    mutation: '_Mutation',
    subscription: '_Subscription',
  }
end
