require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DecimalScalar

class DecimalScalarScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    assert_equal(true, DESCRIBED_CLASS.valid_input?('1.0'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('10.0'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('10.00'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('100.000'))
    assert_equal(false, DESCRIBED_CLASS.valid_input?(10))
  end

  def test_valid_output_ask
    assert_equal(true, DESCRIBED_CLASS.valid_output?(10.0))
  end

  def test_as_json
    assert_equal('10.0', DESCRIBED_CLASS.as_json(10))
  end

  def test_deserialize
    assert_kind_of(BigDecimal, DESCRIBED_CLASS.deserialize(1.0))
  end
end