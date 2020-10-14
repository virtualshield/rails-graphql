require 'config'

class GraphQL_Type_Scalar_FloatScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::FloatScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?(1.0))

    refute(DESCRIBED_CLASS.valid_input?('12'))
    refute(DESCRIBED_CLASS.valid_input?(10))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?(1.0))

    refute(DESCRIBED_CLASS.valid_input?(false))
  end

  def test_as_json_ask
    assert_kind_of(Float, DESCRIBED_CLASS.as_json(10))
  end
end
