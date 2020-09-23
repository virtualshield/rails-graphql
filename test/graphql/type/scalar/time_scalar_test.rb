require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::TimeScalar

class TimeScalarTest < GraphQL::TestCase
  def test_valid_input_is_valid
    assert_equal(DESCRIBED_CLASS.valid_input?('02:12'), true)
  end

  def test_valid_input_is_invalid
    assert_equal(DESCRIBED_CLASS.valid_input?('a'), false)
  end

  def test_valid_output_is_valid
    assert_equal(DESCRIBED_CLASS.valid_output?('12:12'.to_time), true)
  end

  def test_valid_output_is_invalid
    assert_equal(DESCRIBED_CLASS.valid_output?('a'.to_time), false)
  end

  def test_as_json
    assert_equal(DESCRIBED_CLASS.as_json('12:12:12'.to_time), '12:12:12.000000')
  end

  def test_deserialize
    assert_kind_of(Time, DESCRIBED_CLASS.deserialize('01:00'))
  end

  def test_deserialize_output
    assert_equal(DESCRIBED_CLASS.deserialize('01:00'), '2000-01-01 01:00:00 -0200')
  end
end