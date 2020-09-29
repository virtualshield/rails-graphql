require 'config'

class IdScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::IdScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?(12345))
    assert(DESCRIBED_CLASS.valid_input?('bt3btb3t3'))
    assert(DESCRIBED_CLASS.valid_input?(SecureRandom.uuid))

    refute(DESCRIBED_CLASS.valid_input?(12.0))
  end

  def test_as_json
    str = 'Sample'.encode(Encoding::ISO_8859_1)
    result = DESCRIBED_CLASS.as_json(str)

    assert_equal('Sample', result)
    assert_equal(Encoding::UTF_8, result.encoding)
  end

  def test_deserialize
    assert_kind_of(String, DESCRIBED_CLASS.deserialize('foo'))
    assert_equal('foo', DESCRIBED_CLASS.deserialize('foo'))
  end
end
