require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::IntScalar

class IntScalarTest < GraphQL::TestCase
  def test_valid_input_with_valid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(12345), true)
  end

  def test_valid_input_with_invalid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(12.0), false)
  end

  def test_valid_input_outside_range
    assert_equal(DESCRIBED_CLASS.valid_input?(2147483649), false)
  end

  def test_valid_output_with_valid
    assert_equal(DESCRIBED_CLASS.valid_output?(12345), true)
  end

  def test_valid_output_with_invalid
    assert_equal(DESCRIBED_CLASS.valid_output?(2147483649), false)
  end

  def test_as_json_valid
    assert_equal(DESCRIBED_CLASS.as_json(123), 123)
  end

  def test_as_json_invalid
    assert_nil(DESCRIBED_CLASS.as_json(2147483649), nil)
  end
end