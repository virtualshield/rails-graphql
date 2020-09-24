require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::StringScalar

class StringScalarTest < GraphQL::TestCase
  def test_as_json_ask
    str = 'Sample'.encode(Encoding::ISO_8859_1)
    result = DESCRIBED_CLASS.as_json(str)
    assert_equal(DESCRIBED_CLASS.as_json(1), '1')
    assert_equal(DESCRIBED_CLASS.as_json(nil), '')
    assert_equal(DESCRIBED_CLASS.as_json('a'), 'a')
    assert_equal("Sample", result)
    assert_equal(result.encoding, Encoding::UTF_8)
  end
end


