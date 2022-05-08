require 'config'

class GraphQL_Type_Scalar_AnyScalarTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::Type::Scalar::AnyScalar

  OBJECTS = {
    1 => [1, '1'],
    'a' => ['a', '"a"'],
    true => [true, 'true'],
    4.2 => [4.2, '4.2'],
    [1, 'a'] => [[1, 'a'], '[1,"a"]'],
    { a: 1, b: 'c' } => [{ 'a' => 1, 'b' => 'c' }, '{"a":1,"b":"c"}'],
  }

  def test_valid_input_ask
    OBJECTS.each_value do |(val, _)|
      assert(DESCRIBED_CLASS.valid_input?(val))
    end
  end

  def test_valid_output_ask
    OBJECTS.each_value do |(val, _)|
      assert(DESCRIBED_CLASS.valid_output?(val))
    end
  end

  def test_to_json
    OBJECTS.each do |source, (_, val)|
      assert_equal(val, DESCRIBED_CLASS.to_json(source))
    end
  end

  def test_as_json
    OBJECTS.each do |source, (val, _)|
      assert_equal(val, DESCRIBED_CLASS.as_json(source))
    end
  end
end
