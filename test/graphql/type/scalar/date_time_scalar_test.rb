require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DateTimeScalar

class DateTimeScalarTest < GraphQL::TestCase
  def test_valid_input_int_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_input?(1), false)
  end

  def test_valid_input_string_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_input?('abc'), false)
  end

  def test_valid_input_nil_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_input?(nil), false)
  end

  def test_valid_input_datetime_is_datetime
    datetime = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')
    assert_equal(DESCRIBED_CLASS.valid_input?(datetime), true)
  end

  def test_valid_output_int_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_output?(1), false)
  end

  def test_valid_output_nil_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_output?(nil), false)
  end

  def test_valid_output_string_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_output?('abc'), true)
  end

  def test_as_json_string_datetime_to_datetime
    assert_equal(DESCRIBED_CLASS.as_json('2020-02-02'), "2020-02-02T00:00:00-03:00")
  end

  def test_deserialize_string_datetime_to_datetime
    assert_kind_of(Time, DESCRIBED_CLASS.deserialize('2020-02-02T00:00:00-03:00'))
  end
end