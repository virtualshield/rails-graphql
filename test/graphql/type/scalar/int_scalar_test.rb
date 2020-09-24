require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::IntScalar

class IntScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    assert_equal(true, DESCRIBED_CLASS.valid_input?(12345))
    assert_equal(false, DESCRIBED_CLASS.valid_input?(12.0))
    assert_equal(true, DESCRIBED_CLASS.valid_input?(2147483647))
    assert_equal(false, DESCRIBED_CLASS.valid_input?(2147483649))
    assert_equal(false, DESCRIBED_CLASS.valid_input?('2147483649'))
  end

  def test_valid_output_with_ask
    assert_equal(true, DESCRIBED_CLASS.valid_output?(12345))
    assert_equal(false, DESCRIBED_CLASS.valid_output?(2147483649))
    assert_equal(false, DESCRIBED_CLASS.valid_output?('2147483649'))
  end

  def test_as_json_ask
    assert_equal(123, DESCRIBED_CLASS.as_json(123))
    assert_nil(nil, DESCRIBED_CLASS.as_json(2147483649))
  end
end