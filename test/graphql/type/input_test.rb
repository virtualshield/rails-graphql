require 'config'

class InputTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Type::Input)

  def test_gql_name
    DESCRIBED_CLASS.stub_ivar(:@gql_name, 'sample') do
      assert_equal('sample', DESCRIBED_CLASS.gql_name)
    end

    DESCRIBED_CLASS.stub(:name, 'GraphQL::TestInput') do
      other = Class.new(Rails::GraphQL::Type::Input)
      other.stub(:name, 'GraphQL::Other') do
        stubbed_config(:auto_suffix_input_objects) do
          assert_equal('Test', DESCRIBED_CLASS.gql_name)
          DESCRIBED_CLASS.remove_instance_variable(:@gql_name)

          assert_equal('Other', other.gql_name)
          other.remove_instance_variable(:@gql_name)
        end

        stubbed_config(:auto_suffix_input_objects, 'Sample') do
          assert_equal('TestSample', DESCRIBED_CLASS.gql_name)
          DESCRIBED_CLASS.remove_instance_variable(:@gql_name)

          assert_equal('OtherSample', other.gql_name)
          other.remove_instance_variable(:@gql_name)
        end
      end

      stubbed_config(:auto_suffix_input_objects, 'Input') do
        assert_equal('TestInput', DESCRIBED_CLASS.gql_name)
        DESCRIBED_CLASS.remove_instance_variable(:@gql_name)
      end
    end
  end

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?(nil))

    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?('abc'))

    field = double(gql_name: 'a', valid_input?: ->(value) { value != 'c' })
    DESCRIBED_CLASS.stub(:enabled_fields, [field]) do
      DESCRIBED_CLASS.stub(:build_defaults, { 'a' => nil }) do
        assert(DESCRIBED_CLASS.valid_input?({}))
        assert(DESCRIBED_CLASS.valid_input?({ 'a' => 'a' }))
        refute(DESCRIBED_CLASS.valid_input?({ 'b' => 'b' }))
      end

      DESCRIBED_CLASS.stub(:build_defaults, { 'a' => 'a' }) do
        assert(DESCRIBED_CLASS.valid_input?({}))
        assert(DESCRIBED_CLASS.valid_input?({ 'a' => 'b' }))
        refute(DESCRIBED_CLASS.valid_input?({ 'a' => 'c' }))
      end
    end
  end
end
