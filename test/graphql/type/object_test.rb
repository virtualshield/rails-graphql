require 'config'

DESCRIBED_CLASS = Class.new(Rails::GraphQL::Type::Object)

class ObjectTest < GraphQL::TestCase
  def test_valid_member_with_all_fields
    fields = {
      name: OpenStruct.new(method_name: :name),
      age:  OpenStruct.new(method_name: :age),
    }
    assert_equal(DESCRIBED_CLASS.valid_member?(fields), true)
  end

  def test_valid_ostruct_member_with_one_field
    fields = {
      name: OpenStruct.new(method_name: :name),
      age:  nil,
    }
    assert_equal(DESCRIBED_CLASS.valid_member?(fields), true)
  end

  def test_valid_ostruct_member_with_one_field
    fields = {
      name: OStruct.new(method_name: :name),
      age:  OpenStruct.new(method_name: :age),
    }
    assert_equal(DESCRIBED_CLASS.valid_member?(fields), true)
  end

  def test_valid_ostruct_member_with_one_field
    fields = {
      "name": "name",
      "age":  "age",
    }
    assert_equal(DESCRIBED_CLASS.valid_member?(fields), true)
  end

  def test_valid_ostruct_member_with_one_field
    fields = {
      "name": "name",
      "age":  "age",
    }
    assert_equal(DESCRIBED_CLASS.valid_member?(fields), true)
  end
  
end
