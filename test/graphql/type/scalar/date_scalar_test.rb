require 'config'

class DateScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::DateScalar

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?('2020-02-02'))

    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?('abc'))
    refute(DESCRIBED_CLASS.valid_input?(nil))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?('2020-02-02'))

    refute(DESCRIBED_CLASS.valid_output?('abc'))
    refute(DESCRIBED_CLASS.valid_output?(nil))
    refute(DESCRIBED_CLASS.valid_output?(1))
  end

  def test_as_json
    assert_equal('2020-02-02', DESCRIBED_CLASS.as_json('2020-02-02'))
  end

  def test_deserialize
    assert_kind_of(Date, DESCRIBED_CLASS.deserialize('2020-02-02'))
  end
end
