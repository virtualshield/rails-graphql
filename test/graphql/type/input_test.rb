require 'config'

GraphQL::TestInput = Class.new(Rails::GraphQL::Type::Input)
GraphQL::Other = Class.new(Rails::GraphQL::Type::Input)

class InputTest < GraphQL::TestCase
  def test_gql_name
    mocked_gql_name('test') do
      assert_equal('test', GraphQL::TestInput.gql_name)
    end

    mocked_auto_suffix_input_objects(nil) do
      assert_equal('Test', GraphQL::TestInput.gql_name)
      GraphQL::TestInput.remove_instance_variable(:@gql_name)
    end

    mocked_auto_suffix_input_objects('Input') do
      assert_equal('TestInput', GraphQL::TestInput.gql_name)
      # BUG: It is not working with simple class name
      # assert_equal('OtherInput', GraphQL::Other.gql_name)
    end
  end

  def test_valid_input_ask
    assert(GraphQL::TestInput.valid_input?(nil))
    refute(GraphQL::TestInput.valid_input?(1))
    refute(GraphQL::TestInput.valid_input?('abc'))

    field = OpenStruct.new(gql_name: 'a')
    field.define_singleton_method(:valid_input?) { |value| value != 'c' }

    GraphQL::TestInput.stub(:enabled_fields, [field]) do
      GraphQL::TestInput.stub(:build_defaults, { 'a' => nil }) do
        assert(GraphQL::TestInput.valid_input?({}))
        assert(GraphQL::TestInput.valid_input?({ 'a' => 'a' }))
        refute(GraphQL::TestInput.valid_input?({ 'b' => 'b' }))
      end

      GraphQL::TestInput.stub(:build_defaults, { 'a' => 'a' }) do
        assert(GraphQL::TestInput.valid_input?({}))
        assert(GraphQL::TestInput.valid_input?({ 'a' => 'b' }))
        refute(GraphQL::TestInput.valid_input?({ 'a' => 'c' }))
      end
    end
  end


  def mocked_auto_suffix_input_objects(value, &block)
    Rails::GraphQL.config.stub(:auto_suffix_input_objects, value, &block)
  end

  def mocked_gql_name(value, &block)
    GraphQL::TestInput.instance_variable_set(:@gql_name, value)
    yield
    GraphQL::TestInput.remove_instance_variable(:@gql_name)
  end
end