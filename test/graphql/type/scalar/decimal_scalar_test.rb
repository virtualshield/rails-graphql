require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DecimalScalar

class DecimalScalarScalarTest < GraphQL::TestCase
  def test_valid_input_valid_value
    assert_equal(DESCRIBED_CLASS.valid_input?('10.0'), true)
  end

  def test_valid_input_invalid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(10), false)
  end

  def test_valid_output_is_valid
    assert_equal(DESCRIBED_CLASS.valid_output?(10.0), true)
  end

  def test_as_json
    assert_equal(DESCRIBED_CLASS.as_json(10), '10.0')
  end

  def test_deserialize
    assert_kind_of(BigDecimal, DESCRIBED_CLASS.deserialize(1.0))
  end
end