require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DateScalar

class DateScalarTest < GraphQL::TestCase
  def test_valid_input_int_is_date
    assert_equal(DESCRIBED_CLASS.valid_input?(1), false)
  end

  def test_valid_input_string_is_date
    assert_equal(DESCRIBED_CLASS.valid_input?('abc'), false)
  end

  def test_valid_input_nil_is_date
    assert_equal(DESCRIBED_CLASS.valid_input?(nil), false)
  end

  def test_valid_input_date_is_date
    assert_equal(DESCRIBED_CLASS.valid_input?('2020-02-02'), true)
  end

  def test_valid_output_string_is_date
    assert_equal(DESCRIBED_CLASS.valid_output?('abc'), true)
  end

  def test_valid_output_string_date_is_date
    assert_equal(DESCRIBED_CLASS.valid_output?('2020-02-02'), true)
  end

  def test_valid_output_nil_is_date
    assert_equal(DESCRIBED_CLASS.valid_output?(nil), false)
  end

  def test_valid_output_int_is_date
    assert_equal(DESCRIBED_CLASS.valid_output?(1), false)
  end

  def test_as_json_string_date_to_date
    assert_equal(DESCRIBED_CLASS.as_json('2020-02-02'), '2020-02-02')
  end

  def test_deserialize_string_date_is_date
    assert_kind_of(Date, DESCRIBED_CLASS.deserialize('2020-02-02'))
  end
end