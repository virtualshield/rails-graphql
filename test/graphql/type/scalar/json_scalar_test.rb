require 'config'

class GraphQL_Type_Scalar_JsonScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::JsonScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?({}))
    refute(DESCRIBED_CLASS.valid_input?(1))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?({}))
    refute(DESCRIBED_CLASS.valid_output?(1))
  end

  def test_to_json
    assert_equal('{"a":1}', DESCRIBED_CLASS.to_json({ a: 1 }))
  end

  def test_as_json
    assert_equal({ 'a' => 1 }, DESCRIBED_CLASS.as_json({ a: 1 }))
  end
end
