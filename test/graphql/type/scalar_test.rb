require 'config'

class GraphQL_Type_ScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = unmapped_class(Rails::GraphQL::Type::Scalar)

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?("abc"))
    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?(nil))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?(1))
    assert(DESCRIBED_CLASS.valid_output?(nil))
    assert(DESCRIBED_CLASS.valid_output?("abc"))
  end

  def test_to_json
    assert_equal("\"1\"", DESCRIBED_CLASS.to_json(1))
    assert_equal("\"abc\"", DESCRIBED_CLASS.to_json('abc'))
    assert_equal("\"\"", DESCRIBED_CLASS.to_json(nil))
  end

  def test_as_json
    assert_equal('abc', DESCRIBED_CLASS.as_json('abc'))
    assert_equal('1', DESCRIBED_CLASS.as_json(1))
    assert_equal('', DESCRIBED_CLASS.as_json(nil))
  end

  def test_deserialize
    assert_nil(DESCRIBED_CLASS.deserialize(nil))
    assert_equal('abc', DESCRIBED_CLASS.deserialize('abc'))
    assert_equal(1, DESCRIBED_CLASS.deserialize(1))
  end

  def test_inspect
    DESCRIBED_CLASS.stub(:name, 'GraphQL::TestScalar') do
      assert_equal('#<GraphQL::Scalar Test>', DESCRIBED_CLASS.inspect)
    end

    DESCRIBED_CLASS.stub(:name, 'GraphQL::Test') do
      assert_equal('#<GraphQL::Scalar Test>', DESCRIBED_CLASS.inspect)
    end
  end
end
