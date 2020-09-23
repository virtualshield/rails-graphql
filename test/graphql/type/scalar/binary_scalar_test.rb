require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BinaryScalar

class BinaryScalarTest < GraphQL::TestCase
  def test_as_json_integer_to_string
    assert_equal(DESCRIBED_CLASS.as_json(1), 'MQ==')
  end

  def test_as_json_nil_to_string
    assert_equal(DESCRIBED_CLASS.as_json(nil), '')
  end

  def test_as_json_string_to_string
    assert_equal(DESCRIBED_CLASS.as_json('a'), 'YQ==')
  end

  def test_deserialize_is_class
    assert_kind_of(ActiveModel::Type::Binary::Data, DESCRIBED_CLASS.deserialize(File.read("test/assets/luke.jpg")))
  end
end