require 'config'

class BinaryScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BinaryScalar
  FILE_PATH = Pathname.new(__dir__).join('../../../assets/luke.jpg')

  def test_as_json
    assert_equal('MQ==', DESCRIBED_CLASS.as_json(1))
    assert_equal('YQ==', DESCRIBED_CLASS.as_json('a'))
    assert_equal('', DESCRIBED_CLASS.as_json(nil))
  end

  def test_deserialize
    file = DESCRIBED_CLASS.deserialize(File.read(FILE_PATH))
    assert_kind_of(ActiveModel::Type::Binary::Data, file)
  end
end
