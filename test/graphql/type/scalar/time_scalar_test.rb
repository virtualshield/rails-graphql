require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::TimeScalar

class TimeScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    assert_equal(true, DESCRIBED_CLASS.valid_input?('1:12'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('12:12'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('123:12'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('12:12:12'))
    assert_equal(true, DESCRIBED_CLASS.valid_input?('12:12:12.123'))
    assert_equal(false, DESCRIBED_CLASS.valid_input?('foo'))
  end

  def test_valid_output_ask
    assert_equal(true, DESCRIBED_CLASS.valid_output?('12:12'.to_time))
    assert_equal(true, DESCRIBED_CLASS.valid_output?(DateTime.current))
    assert_equal(true, DESCRIBED_CLASS.valid_output?(Time.current))
    assert_equal(false, DESCRIBED_CLASS.valid_output?('foo'.to_time))
  end

  def test_as_json
    assert_equal('12:12:00.000000', DESCRIBED_CLASS.as_json('12:12'.to_time))
    assert_equal('12:12:12.000000', DESCRIBED_CLASS.as_json('12:12:12'.to_time))
    assert_equal('12:12:12.120000', DESCRIBED_CLASS.as_json('12:12:12.12'.to_time))
  end

  def test_deserialize
    assert_kind_of(Time, DESCRIBED_CLASS.deserialize('01:00'))
    assert_equal("2000-01-01 01:00:00 -0200".to_time, DESCRIBED_CLASS.deserialize('01:00'))
  end
end