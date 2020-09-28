require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DateTimeScalar

class DateTimeScalarTest < GraphQL::TestCase
  def test_valid_input_ask
    datetime = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')

    assert(DESCRIBED_CLASS.valid_input?(datetime))
    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?('abc'))
    refute(DESCRIBED_CLASS.valid_input?(nil))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?('abc'))
    refute(DESCRIBED_CLASS.valid_output?(1))
    refute(DESCRIBED_CLASS.valid_output?(nil))
  end

  def test_as_json
    assert_equal('2020-02-02T00:00:00-03:00', DESCRIBED_CLASS.as_json('2020-02-02'))
  end

  def test_deserialize
    assert_kind_of(Time, DESCRIBED_CLASS.deserialize('2020-02-02T00:00:00-03:00'))
  end
end