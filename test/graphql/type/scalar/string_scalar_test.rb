require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::StringScalar

class StringScalarTest < GraphQL::TestCase
  def test_as_json_integer_to_string
    assert_equal(DESCRIBED_CLASS.as_json(1), '1')
  end
  def test_as_json_nil_to_string
    assert_equal(DESCRIBED_CLASS.as_json(nil), '')
  end

  def test_as_json_string_to_string
    assert_equal(DESCRIBED_CLASS.as_json('a'), 'a')
  end

  def test_as_json_encode_uft
    str = 'Sample'.encode(Encoding::ISO_8859_1)
    result = DESCRIBED_CLASS.as_json(str)
    assert_equal(result, 'Sample')
    assert_equal(result.encoding, Encoding::UTF_8)
  end
end


