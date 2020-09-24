require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::FloatScalar

class FloatScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    assert_equal(true, DESCRIBED_CLASS.valid_input?(1.0))
    assert_equal(false, DESCRIBED_CLASS.valid_input?('12'))
    assert_equal(false, DESCRIBED_CLASS.valid_input?(10))
  end

  def test_valid_output_ask
    assert_equal(true, DESCRIBED_CLASS.valid_output?(1.0))
  end

  def test_as_json_ask
    assert_kind_of(Float, DESCRIBED_CLASS.as_json(10))
  end
end