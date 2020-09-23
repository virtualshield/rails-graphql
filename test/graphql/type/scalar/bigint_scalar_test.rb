require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::BigintScalar

class BigintScalarTest < GraphQL::TestCase
  def test_valid_input_regex_plus
    assert_equal(DESCRIBED_CLASS.valid_input?('+123'), true)
  end

  def test_valid_input_regex_negative
    assert_equal(DESCRIBED_CLASS.valid_input?('-123'), true)
  end

  def test_valid_input_regex_number
    assert_equal(DESCRIBED_CLASS.valid_input?(1), false)
  end

  def test_valid_input_regex_float
    assert_equal(DESCRIBED_CLASS.valid_input?('12,0'), false)
  end

  def test_valid_input_regex_text
    assert_equal(DESCRIBED_CLASS.valid_input?('1abc'), false)
  end

  def test_valid_input_regex_nil
    assert_equal(DESCRIBED_CLASS.valid_input?(nil), false)
  end

  def test_valid_output_int_is_int
    assert_equal(DESCRIBED_CLASS.valid_output?(1), true)
  end

  def test_valid_output_string_is_int
    assert_equal(DESCRIBED_CLASS.valid_output?('abc'), true)
  end

  def test_valid_output_nil_is_int
    assert_equal(DESCRIBED_CLASS.valid_output?(nil), true)
  end

  def test_valid_output_array_is_int
    assert_equal(DESCRIBED_CLASS.valid_output?([1,'abc']), false)
  end

  def test_as_json_integer_to_string
    assert_equal(DESCRIBED_CLASS.as_json(1), '1')
  end
  def test_as_json_nil_to_string
    assert_equal(DESCRIBED_CLASS.as_json(nil), '0')
  end

  def test_as_json_string_to_string
    assert_equal(DESCRIBED_CLASS.as_json('a'), '0')
  end

  def test_deserialize_int_to_int
    assert_equal(DESCRIBED_CLASS.deserialize(1), 1)
  end

  def test_deserialize_string_to_int
    assert_equal(DESCRIBED_CLASS.deserialize('a'), 0)
  end

  def test_deserialize_nil_to_int
    assert_equal(DESCRIBED_CLASS.deserialize(nil), 0)
  end
end
