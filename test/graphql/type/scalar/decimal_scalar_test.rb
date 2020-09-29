require 'config'

class DecimalScalarScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DecimalScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?('1.0'))
    assert(DESCRIBED_CLASS.valid_input?('10.0'))
    assert(DESCRIBED_CLASS.valid_input?('10.00'))
    assert(DESCRIBED_CLASS.valid_input?('100.000'))

    refute(DESCRIBED_CLASS.valid_input?(10))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?(10.0))

    refute(DESCRIBED_CLASS.valid_output?(false))
  end

  def test_as_json
    assert_equal('10.0', DESCRIBED_CLASS.as_json(10))
  end

  def test_deserialize
    assert_kind_of(BigDecimal, DESCRIBED_CLASS.deserialize(1.0))
  end
end
