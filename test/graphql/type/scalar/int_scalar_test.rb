require 'config'

class IntScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::IntScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?(12345))
    assert(DESCRIBED_CLASS.valid_input?(2147483647))

    refute(DESCRIBED_CLASS.valid_input?(12.0))
    refute(DESCRIBED_CLASS.valid_input?(2147483649))
    refute(DESCRIBED_CLASS.valid_input?('2147483649'))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?(12345))

    refute(DESCRIBED_CLASS.valid_output?(2147483649))
    refute(DESCRIBED_CLASS.valid_output?('2147483649'))
  end

  def test_as_json
    assert_equal(123, DESCRIBED_CLASS.as_json(123))
    assert_nil(nil, DESCRIBED_CLASS.as_json(2147483649))
  end
end
