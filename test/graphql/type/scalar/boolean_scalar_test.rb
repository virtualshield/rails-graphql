require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BooleanScalar

class BooleanScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    assert_equal(true, DESCRIBED_CLASS.valid_input?(true))
    assert_equal(true, DESCRIBED_CLASS.valid_input?(false))
    assert_equal(false, DESCRIBED_CLASS.valid_input?(nil))
    assert_equal(false, DESCRIBED_CLASS.valid_input?(1))
    assert_equal(false, DESCRIBED_CLASS.valid_input?('true'))
  end

  def test_valid_output_ask
    assert_equal(true, DESCRIBED_CLASS.valid_output?(true))
    assert_equal(true, DESCRIBED_CLASS.valid_output?(false))
    assert_equal(true, DESCRIBED_CLASS.valid_output?(nil))
  end

  def test_as_json
    assert_equal(true, DESCRIBED_CLASS.as_json(true))
    assert_equal(true, DESCRIBED_CLASS.as_json([1]))
    assert_equal(false, DESCRIBED_CLASS.as_json([]))
    assert_equal(true, DESCRIBED_CLASS.as_json('abc'))
    assert_equal(false, DESCRIBED_CLASS.as_json(''))
    assert_equal(false, DESCRIBED_CLASS.as_json(nil))
  end


  def test_deserialize
    assert_equal(true, DESCRIBED_CLASS.deserialize(nil))
    assert_equal(false, DESCRIBED_CLASS.deserialize(0))
    assert_equal(true, DESCRIBED_CLASS.deserialize(1))
    assert_equal(true, DESCRIBED_CLASS.deserialize('abc'))
    assert_equal(true, DESCRIBED_CLASS.deserialize(true))
    assert_equal(false, DESCRIBED_CLASS.deserialize(false))
  end
end