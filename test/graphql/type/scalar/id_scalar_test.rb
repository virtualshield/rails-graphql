require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::IdScalar

class IdScalarTest < GraphQL::TestCase
  def test_valid_input_valid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(12345), true)
  end

  def test_valid_input_invalid_value
    assert_equal(DESCRIBED_CLASS.valid_input?(12.0), false)
  end

  def test_as_json_encode_uft
    str = 'Sample'.encode(Encoding::UTF_8)
    result = DESCRIBED_CLASS.as_json(str)
    assert_equal(result, "Sample")
    assert_equal(result.encoding, Encoding::UTF_8)
  end

  def deserialize
    assert_kind_of(String, DESCRIBED_CLASS.valid_input?("foo"))
  end
end