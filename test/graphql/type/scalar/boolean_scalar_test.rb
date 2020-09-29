require 'config'

class BooleanScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BooleanScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?(true))
    assert(DESCRIBED_CLASS.valid_input?(false))

    refute(DESCRIBED_CLASS.valid_input?(nil))
    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?('true'))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?(true))
    assert(DESCRIBED_CLASS.valid_output?(false))
    assert(DESCRIBED_CLASS.valid_output?(nil))
  end

  def test_as_json
    assert(DESCRIBED_CLASS.as_json(true))
    assert(DESCRIBED_CLASS.as_json([1]))
    assert(DESCRIBED_CLASS.as_json('abc'))

    refute(DESCRIBED_CLASS.as_json([]))
    refute(DESCRIBED_CLASS.as_json(''))
    refute(DESCRIBED_CLASS.as_json(nil))
  end

  def test_deserialize
    assert(DESCRIBED_CLASS.deserialize(nil))
    assert(DESCRIBED_CLASS.deserialize(1))
    assert(DESCRIBED_CLASS.deserialize('abc'))
    assert(DESCRIBED_CLASS.deserialize(true))

    refute(DESCRIBED_CLASS.deserialize(0))
    refute(DESCRIBED_CLASS.deserialize(false))
  end
end
