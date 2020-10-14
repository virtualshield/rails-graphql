require 'config'

class GraphQL_Type_Scalar_TimeScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::TimeScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?('1:12'))
    assert(DESCRIBED_CLASS.valid_input?('12:12'))
    assert(DESCRIBED_CLASS.valid_input?('123:12'))
    assert(DESCRIBED_CLASS.valid_input?('12:12:12'))
    assert(DESCRIBED_CLASS.valid_input?('12:12:12.123'))

    refute(DESCRIBED_CLASS.valid_input?('foo'))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?('12:12'.to_time))
    assert(DESCRIBED_CLASS.valid_output?(DateTime.current))
    assert(DESCRIBED_CLASS.valid_output?(Time.current))

    refute(DESCRIBED_CLASS.valid_output?('foo'.to_time))
  end

  def test_as_json
    assert_equal('12:12:00.000000', DESCRIBED_CLASS.as_json('12:12'.to_time))
    assert_equal('12:12:12.000000', DESCRIBED_CLASS.as_json('12:12:12'.to_time))
    assert_equal('12:12:12.120000', DESCRIBED_CLASS.as_json('12:12:12.12'.to_time))
  end

  def test_deserialize
    Time.use_zone('UTC') do
      assert_kind_of(Time, DESCRIBED_CLASS.deserialize('01:00'))
      assert_equal('2000-01-01 01:00:00 -0000'.to_time, DESCRIBED_CLASS.deserialize('01:00'))
    end
  end
end
