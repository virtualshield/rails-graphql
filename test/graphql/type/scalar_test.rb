require 'config'

GraphQL::TestScalar = Class.new(Rails::GraphQL::Type::Scalar)

class ScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    assert(GraphQL::TestScalar.valid_input?("abc"))
    assert_equal(false, GraphQL::TestScalar.valid_input?(1))
    assert_equal(false, GraphQL::TestScalar.valid_input?(nil))
  end

  def test_valid_output_ask
    assert(GraphQL::TestScalar.valid_output?(1))
    assert(GraphQL::TestScalar.valid_output?(nil))
    assert(GraphQL::TestScalar.valid_output?("abc"))
  end


  def test_to_json
    assert_equal("\"1\"", GraphQL::TestScalar.to_json(1))
    assert_equal("\"abc\"", GraphQL::TestScalar.to_json('abc'))
    assert_equal("\"\"", GraphQL::TestScalar.to_json(nil))
  end

  def test_as_json
    assert_equal('abc', GraphQL::TestScalar.as_json('abc'))
    assert_equal('1', GraphQL::TestScalar.as_json(1))
    assert_equal('', GraphQL::TestScalar.as_json(nil))
  end


  def test_deserialize
    assert_nil(GraphQL::TestScalar.deserialize(nil))
    assert_equal('abc', GraphQL::TestScalar.deserialize('abc'))
    assert_equal(1, GraphQL::TestScalar.deserialize(1))
  end

  def test_inspect
    assert_equal('#<GraphQL::Scalar Test>', GraphQL::TestScalar.inspect)
  end
end