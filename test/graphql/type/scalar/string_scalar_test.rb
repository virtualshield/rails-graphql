require 'config'

class GraphQL_Type_Scalar_StringScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::StringScalar

  def test_as_json
    assert_equal('1', DESCRIBED_CLASS.as_json(1))
    assert_equal('', DESCRIBED_CLASS.as_json(nil))
    assert_equal('a', DESCRIBED_CLASS.as_json('a'))

    str = 'Sample'.encode(Encoding::ISO_8859_1)
    result = DESCRIBED_CLASS.as_json(str)

    assert_equal('Sample', result)
    assert_equal(result.encoding, Encoding::UTF_8)
  end
end
