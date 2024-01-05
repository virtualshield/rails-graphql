require 'config'

class GraphQL_Request_Component_OperationTest < GraphQL::TestCase
  def test_build
    request = Object.new
    request.define_singleton_method(:build) { |klass, *| klass }

    assert_equal(klass::Query, klass.build(request, new_token('', :query)))
    assert_equal(klass::Mutation, klass.build(request, new_token('', :mutation)))
    assert_equal(klass::Subscription, klass.build(request, new_token('', :subscription)))

    assert_raises(Rails::GraphQL::NameError) { klass.build(request, new_token('', '')) }
    assert_raises(Rails::GraphQL::NameError) { klass.build(request, new_token('', :field)) }
  end

  private

  def klass
    Rails::GraphQL::Request::Component::Operation
  end
end
