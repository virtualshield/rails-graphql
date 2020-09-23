require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BooleanScalar

class BooleanScalarTest < GraphQL::TestCase
  def test_valid_input_bool_true_is_bool
    assert_equal(DESCRIBED_CLASS.valid_input?(true), true)
  end

  def test_valid_input_bool_false_is_bool
    assert_equal(DESCRIBED_CLASS.valid_input?(false), true)
  end

  def test_valid_input_nil_is_bool
    assert_equal(DESCRIBED_CLASS.valid_input?(nil), false)
  end

  def test_valid_input_int_is_bool
    assert_equal(DESCRIBED_CLASS.valid_input?(1), false)
  end

  def test_valid_input_string_is_bool
    assert_equal(DESCRIBED_CLASS.valid_input?('true'), false)
  end

  def test_valid_output_bool_true
    assert_equal(DESCRIBED_CLASS.valid_output?(true), true)
  end

  def test_valid_output_bool_false
    assert_equal(DESCRIBED_CLASS.valid_output?(true), true)
  end

  def test_valid_output_nil
    assert_equal(DESCRIBED_CLASS.valid_output?(nil), true)
  end

  def test_as_json_present_bool
    assert_equal(DESCRIBED_CLASS.as_json(true), true)
  end

  def test_as_json_present_array
    assert_equal(DESCRIBED_CLASS.as_json([1]), true)
  end

  def test_as_json_present_empty_array
    assert_equal(DESCRIBED_CLASS.as_json([]), false)
  end

  def test_as_json_present_string
    assert_equal(DESCRIBED_CLASS.as_json('abc'), true)
  end

  def test_as_json_present_empty_string
    assert_equal(DESCRIBED_CLASS.as_json(''), false)
  end

  def test_as_json_present_nil
    assert_equal(DESCRIBED_CLASS.as_json(nil), false)
  end

  def test_deserialize_bool_nil
    assert_equal(DESCRIBED_CLASS.deserialize(nil), true)
  end

  def test_deserialize_bool_zero
    assert_equal(DESCRIBED_CLASS.deserialize(0), false)
  end

  def test_deserialize_bool_int
    assert_equal(DESCRIBED_CLASS.deserialize(1), true)
  end

  def test_deserialize_bool_string
    assert_equal(DESCRIBED_CLASS.deserialize('abc'), true)
  end

  def test_deserialize_bool_true
    assert_equal(DESCRIBED_CLASS.deserialize(true), true)
  end

  def test_deserialize_bool_false
    assert_equal(DESCRIBED_CLASS.deserialize(false), false)
  end
end