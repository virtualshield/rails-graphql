require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BinaryScalar

class BinaryScalarTest < GraphQL::TestCase
  def test_as_json
    assert_equal('MQ==', DESCRIBED_CLASS.as_json(1))
    assert_equal('YQ==', DESCRIBED_CLASS.as_json('a'))
    assert_equal('', DESCRIBED_CLASS.as_json(nil))
  end

  def test_deserialize
    assert_kind_of(ActiveModel::Type::Binary::Data, DESCRIBED_CLASS.deserialize(File.read("test/assets/luke.jpg")))
  end
end