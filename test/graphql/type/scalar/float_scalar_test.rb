require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::FloatScalar

class FloatScalarTest < GraphQL::TestCase
  def test_valid_input_valid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(1.0), true)
  end

  def test_valid_input_invalid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(10), false)
  end

  def test_valid_output_with_valid
    assert_equal(DESCRIBED_CLASS.valid_output?(1.0), true)
  end

  def test_as_json_valid
    assert_kind_of(Float, DESCRIBED_CLASS.as_json(10))
  end
end