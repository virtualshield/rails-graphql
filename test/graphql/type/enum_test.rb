require 'config'

GraphQL::TestEnum = Class.new(Rails::GraphQL::Type::Enum)
GraphQL::TestEnum.add('A')
GraphQL::TestEnum.add('B')
GraphQL::TestEnum.add('C')

class EnumTest < GraphQL::TestCase
  def test_indexed
    refute(GraphQL::TestEnum.indexed?)
    GraphQL::TestEnum.indexed!
    assert(GraphQL::TestEnum.indexed?)
  end

  def test_valid_input_ask
    refute(GraphQL::TestEnum.valid_input?(1))
    refute(GraphQL::TestEnum.valid_input?(nil))
    refute(GraphQL::TestEnum.valid_input?('abc'))
  end

  def test_valid_output_ask
    refute(GraphQL::TestEnum.valid_output?(nil))
    refute(GraphQL::TestEnum.valid_output?('abc'))
  end

  def test_to_json
    assert_nil(GraphQL::TestEnum.to_json(nil))
  end

  def test_as_json
    assert_nil(GraphQL::TestEnum.as_json(nil))

    test_value = GraphQL::TestEnum.new('A')
    assert_equal('A', GraphQL::TestEnum.as_json(test_value))

    GraphQL::TestEnum.stub(:indexed?, true) do
      assert_equal('B', GraphQL::TestEnum.as_json(1))
    end

    GraphQL::TestEnum.stub(:indexed?, false) do
      assert_equal('1', GraphQL::TestEnum.as_json(1))
    end

    assert_equal('ABC', GraphQL::TestEnum.as_json('abc'))
  end

  def test_deserialize
    assert_nil(GraphQL::TestEnum.deserialize(nil))
    assert_nil(GraphQL::TestEnum.deserialize('X'))

    test_value = GraphQL::TestEnum.deserialize('A')
    assert_instance_of(GraphQL::TestEnum, test_value)
  end

  def test_add_directives
    assert_raises(StandardError) { GraphQL::TestEnum.add(nil) }
    assert_raises(StandardError) { GraphQL::TestEnum.add(1) }
    assert_raises(StandardError) { GraphQL::TestEnum.add('') }

    GraphQL::TestEnum.stub(:all_values, %w[A B C]) do
      assert_raises(StandardError) { GraphQL::TestEnum.add('A') }

      GraphQL::TestEnum.add('D')

      mocked_new_deprecated_klass do
        mocked_directives_to_set do
          GraphQL::TestEnum.add('D', deprecated: 'done')
          assert_equal(['DeprecatedDirective'], GraphQL::TestEnum.value_directives['D'])
        end

        mocked_directives_to_set do
          GraphQL::TestEnum.add('D', directives: 'Other', deprecated: 'done')
          assert_equal(['Other', 'DeprecatedDirective'], GraphQL::TestEnum.value_directives['D'])
        end
      end
    end
  end

  PASSTHROUGH = ->(x) { x }
  class TestDirective < Rails::GraphQL::Directive; end
  class TestMissingDirective < Rails::GraphQL::Directive; end
  def test_value_using_ask
    assert_raises(StandardError) { GraphQL::TestEnum.value_using?(nil, GraphQL::TestEnum) }

    test_values = { 'B' => [], 'C' => [TestDirective.new] }

    GraphQL::TestEnum.stub(:as_json, PASSTHROUGH) do
      GraphQL::TestEnum.stub(:value_directives, test_values) do
        refute(GraphQL::TestEnum.value_using?('A', TestDirective))
        refute(GraphQL::TestEnum.value_using?('B', TestDirective))
        refute(GraphQL::TestEnum.value_using?('C', TestMissingDirective))

        assert(GraphQL::TestEnum.value_using?('C', TestDirective))
      end
    end
  end

  def test_all_deprecated_values
    assert_kind_of(Hash, GraphQL::TestEnum.all_deprecated_values)
  end

  def test_all_directives
    assert_kind_of(Set, GraphQL::TestEnum.all_directives)
  end

  def test_inspect
    GraphQL::TestEnum.stub(:all_values, %w[]) do
      assert_equal('#<GraphQL::Enum Test (0) {}>', GraphQL::TestEnum.inspect)
    end
  end

  def test_to_sym
    assert_raises(StandardError) { GraphQL::TestEnum.new(nil).to_sym }
    assert_raises(StandardError) { GraphQL::TestEnum.new(1).to_sym }
    assert_equal(:abc, GraphQL::TestEnum.new('ABC').to_sym)
  end

  def test_to_i
    assert_raises(StandardError) { GraphQL::TestEnum.new(nil).to_i }
    assert_raises(StandardError) { GraphQL::TestEnum.new('abc').to_i }

    GraphQL::TestEnum.stub(:all_values, %w[A B C]) do
      assert_equal(1, GraphQL::TestEnum.new('B').to_i)
    end
  end

  def test_valid_ask
    refute(GraphQL::TestEnum.new('ABC').valid?)
    refute(GraphQL::TestEnum.new(nil).valid?)
  end

  def test_description
    GraphQL::TestEnum.stub(:all_value_description, {'description' => 'test'}) do
      assert_nil(GraphQL::TestEnum.new(nil).description)
      assert_nil(GraphQL::TestEnum.new(1).description)
      assert_equal('test', GraphQL::TestEnum.new('description').description)
    end
  end

  def test_directives
    GraphQL::TestEnum.stub(:all_value_directives, {'directive' => 'test'}) do
      assert_nil(GraphQL::TestEnum.new(nil).directives)
      assert_nil(GraphQL::TestEnum.new(1).directives)
      assert_equal('test', GraphQL::TestEnum.new('directive').directives)
    end
  end

  def test_deprecated_ask
    GraphQL::TestEnum.stub(:all_deprecated_values, {'deprecated' => 'test'}) do
      refute(GraphQL::TestEnum.new(nil).deprecated?)
      refute(GraphQL::TestEnum.new(1).deprecated?)
      assert(GraphQL::TestEnum.new('deprecated').deprecated?)
    end
  end

  def mocked_new_deprecated_klass(&block)
    klass = Minitest::Mock.new
    def klass.new(*)
      'DeprecatedDirective'
    end

    GraphQL::TestEnum.stub(:deprecated_klass, klass, &block)
  end

  def mocked_directives_to_set(&block)
    klass = Minitest::Mock.new

    def klass.directives_to_set(directives, *)
      directives
    end

    Rails::GraphQL::Type::Enum.const_set(:GraphQL, klass)

    block.call
    Rails::GraphQL::Type::Enum.send(:remove_const, :GraphQL)
  end
end