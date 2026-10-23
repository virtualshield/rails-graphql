require 'config'

class GraphQL_GlobalIDTest < GraphQL::TestCase
  DESCRIBED_CLASS = unmapped_class(Rails::GraphQL::GlobalID::Serializer)

  def test_klass
    assert(DESCRIBED_CLASS.respond_to?(:klass))
    assert_equal(Rails::GraphQL::GlobalID, DESCRIBED_CLASS.klass)
  end
end
