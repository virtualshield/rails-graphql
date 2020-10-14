require 'config'

class GraphQL_Type_Scalar_BigintScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BigintScalar
  LARGE_VALUE = 123456789101112131415161718192021222324252627282930

  def test_valid_input_ask
    refute(DESCRIBED_CLASS.valid_input?(nil))
    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?('12.0'))
    refute(DESCRIBED_CLASS.valid_input?('1abc'))

    assert(DESCRIBED_CLASS.valid_input?('+123'))
    assert(DESCRIBED_CLASS.valid_input?('-123'))
    assert(DESCRIBED_CLASS.valid_input?(LARGE_VALUE.to_s))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?(1))
    assert(DESCRIBED_CLASS.valid_output?('abc'))
    assert(DESCRIBED_CLASS.valid_output?(nil))
    assert(DESCRIBED_CLASS.valid_output?(LARGE_VALUE))

    refute(DESCRIBED_CLASS.valid_output?([1, 'abc']))
  end

  def test_as_json
    assert_equal('1', DESCRIBED_CLASS.as_json(1))
    assert_equal('0', DESCRIBED_CLASS.as_json(nil))
    assert_equal('0', DESCRIBED_CLASS.as_json('a'))

    assert_equal(LARGE_VALUE.to_s, DESCRIBED_CLASS.as_json(LARGE_VALUE))
  end

  def test_deserialize
    assert_equal(1, DESCRIBED_CLASS.deserialize(1))
    assert_equal(0, DESCRIBED_CLASS.deserialize('a'))
    assert_equal(0, DESCRIBED_CLASS.deserialize(nil))

    assert_equal(LARGE_VALUE, DESCRIBED_CLASS.deserialize(LARGE_VALUE))
  end
end
