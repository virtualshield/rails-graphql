require 'config'

class GraphQL_Type_InputTest < GraphQL::TestCase
  DESCRIBED_CLASS = unmapped_class(Rails::GraphQL::Type::Input)
  OTHER_CLASS = unmapped_class(Rails::GraphQL::Type::Input)

  def test_gql_name
    DESCRIBED_CLASS.stub_ivar(:@gql_name, 'sample') do
      assert_equal('sample', DESCRIBED_CLASS.gql_name)
    end

    DESCRIBED_CLASS.stub(:name, 'GraphQL::TestInput') do
      other = unmapped_class(Rails::GraphQL::Type::Input)
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
    refute(DESCRIBED_CLASS.valid_input?(nil))
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

  def test_deserialize
    field = double(gql_name: 'a', name: 'b', deserialize: passthrough)
    value = [['a', 'atest'], ['b', 'btest']]
    value2 = [['c', 'atest']]

    DESCRIBED_CLASS.stub(:enabled_fields, [field]) do
      result = DESCRIBED_CLASS.deserialize(value)
      assert_instance_of(DESCRIBED_CLASS, result)
      assert_equal('atest', result[:b])

      assert(DESCRIBED_CLASS.deserialize(value2).to_h.blank?)
      assert(DESCRIBED_CLASS.deserialize('test').to_h.blank?)
      assert(DESCRIBED_CLASS.deserialize(1).to_h.blank?)
      assert(DESCRIBED_CLASS.deserialize(nil).to_h.blank?)
    end
  end

  def test_build_defaults
    field = double(gql_name: 'a', default: 'b')
    DESCRIBED_CLASS.stub(:fields?, true) do
      DESCRIBED_CLASS.stub(:enabled_fields, [field]) do
        assert_equal({ 'a' => 'b' }, DESCRIBED_CLASS.build_defaults)
      end
    end

    DESCRIBED_CLASS.stub(:enabled_fields, []) do
      assert_equal({}, DESCRIBED_CLASS.build_defaults)
    end
  end

  def test_inspect
    DESCRIBED_CLASS.stub(:gql_name, 'foo') do
      DESCRIBED_CLASS.stub_ivar(:@fields, {}) do
        assert_equal('#<GraphQL::Input foo>', DESCRIBED_CLASS.inspect)
      end

      DESCRIBED_CLASS.stub_ivar(:@fields, { 'a' => 'a' }) do
        assert_equal('#<GraphQL::Input foo("a")>', DESCRIBED_CLASS.inspect)
      end

      DESCRIBED_CLASS.stub_ivar(:@fields, { 'a' => 'a', 'b' => 'b' }) do
        assert_equal('#<GraphQL::Input foo("a", "b")>', DESCRIBED_CLASS.inspect)
      end
    end
  end

  def test_initialize
    mocked_raise = ->(*) { raise }
    object = OTHER_CLASS.allocate
    object.stub(:validate!, mocked_raise) do
      assert_raises(StandardError) { object.send(:initialize, nil) }

      object.send(:initialize, 'a')
      assert_equal('a', object.args)
      assert(object.args.frozen?)
    end

    mocked = ->(*) { nil }
    object.stub(:validate!, mocked) do
      object.send(:initialize, A: 'B')
      assert_equal('B', object.args.a)
      assert(object.args.frozen?)
    end
  end

  def test_validate_bang
    object = DESCRIBED_CLASS.new({ 'a' => 'b' })

    validate = ->(*) { raise Rails::GraphQL::InvalidValueError }
    field = { 'a' => double(validate_output!: validate) }
    object.stub(:resource, double(gql_name: 'B')) do
      object.stub(:fields, field) do
        assert_raises(Rails::GraphQL::InvalidValueError) { object.validate! }
      end
    end

    counter = 0
    field = { 'a' => double(validate_output!: ->(*) { counter += 1 }) }
    object.stub(:fields, field) do
      object.validate!
      assert_equal(1, counter)
    end
  end
end
