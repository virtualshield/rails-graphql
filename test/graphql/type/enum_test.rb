require 'config'

class EnumTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Type::Enum)
  %w[A B C].each(&DESCRIBED_CLASS.method(:add))

  def test_indexed
    refute(DESCRIBED_CLASS.indexed?)
    DESCRIBED_CLASS.indexed!
    assert(DESCRIBED_CLASS.indexed?)
    DESCRIBED_CLASS.remove_instance_variable(:@indexed)
  end

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?('A'))

    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?(nil))
    refute(DESCRIBED_CLASS.valid_input?('abc'))
  end

  def test_valid_output_ask
    assert(DESCRIBED_CLASS.valid_output?('A'))

    refute(DESCRIBED_CLASS.valid_output?(nil))
    refute(DESCRIBED_CLASS.valid_output?('abc'))
  end

  def test_to_json
    assert_nil(DESCRIBED_CLASS.to_json(nil))
    assert_equal('"A"', DESCRIBED_CLASS.to_json('A'))
  end

  def test_as_json
    assert_nil(DESCRIBED_CLASS.as_json(nil))

    test_value = DESCRIBED_CLASS.new('A')
    assert_equal('A', DESCRIBED_CLASS.as_json(test_value))

    DESCRIBED_CLASS.stub(:indexed?, true) do
      assert_equal('B', DESCRIBED_CLASS.as_json(1))
    end

    DESCRIBED_CLASS.stub(:indexed?, false) do
      assert_equal('1', DESCRIBED_CLASS.as_json(1))
    end

    assert_equal('ABC', DESCRIBED_CLASS.as_json('abc'))
  end

  def test_deserialize
    assert_nil(DESCRIBED_CLASS.deserialize(nil))
    assert_nil(DESCRIBED_CLASS.deserialize('X'))

    test_value = DESCRIBED_CLASS.deserialize('A')
    assert_instance_of(DESCRIBED_CLASS, test_value)
    assert_equal('A', test_value.value)
  end

  def test_decorate
    DESCRIBED_CLASS.stub(:as_json, '2') do
      DESCRIBED_CLASS.stub(:deserialize, '3') do
        assert_equal('3', DESCRIBED_CLASS.decorate('1'))
      end
    end
  end

  def test_add
    assert_raises(StandardError) { DESCRIBED_CLASS.add(nil) }
    assert_raises(StandardError) { DESCRIBED_CLASS.add(1) }
    assert_raises(StandardError) { DESCRIBED_CLASS.add('') }

    DESCRIBED_CLASS.stub(:all_values, %w[A B C]) do
      assert_raises(StandardError) { DESCRIBED_CLASS.add('A') }

      DESCRIBED_CLASS.add('D')
      assert_includes(DESCRIBED_CLASS.values, 'D')
      assert_includes(DESCRIBED_CLASS.value_directives.keys, 'D')

      DESCRIBED_CLASS.add('D', desc: 'Just D')
      assert_includes(DESCRIBED_CLASS.value_description.keys, 'D')
      assert_equal('Just D', DESCRIBED_CLASS.value_description['D'])

      DESCRIBED_CLASS.stub(:deprecated_klass, fake_directive) do
        stubbed_directives_to_set do
          DESCRIBED_CLASS.add('D', deprecated: 'done')
          assert_equal([{ reason: 'done' }], DESCRIBED_CLASS.value_directives['D'])

          DESCRIBED_CLASS.add('D', directives: 'Other', deprecated: true)
          assert_equal(['Other', { reason: nil }], DESCRIBED_CLASS.value_directives['D'])
        end
      end
    end
  end

  def test_value_using_ask
    assert_raises(StandardError) { DESCRIBED_CLASS.value_using?(nil, DESCRIBED_CLASS) }

    test_directive    = Class.new(Rails::GraphQL::Directive)
    missing_directive = Class.new(Rails::GraphQL::Directive)
    test_values = { 'B' => [], 'C' => [test_directive.new] }

    DESCRIBED_CLASS.stub(:as_json, passthrough) do
      DESCRIBED_CLASS.stub(:value_directives, test_values) do
        refute(DESCRIBED_CLASS.value_using?('A', test_directive))
        refute(DESCRIBED_CLASS.value_using?('B', test_directive))
        refute(DESCRIBED_CLASS.value_using?('C', missing_directive))

        assert(DESCRIBED_CLASS.value_using?('C', test_directive))
      end
    end
  end

  def test_all_deprecated_values
    with_reaons = OpenStruct.new(args: double(reason: 'sample'))
    without_reason = OpenStruct.new(args: double(reason: nil))
    test_values = { 'A' => [], 'B' => [''], 'C' => [with_reaons], 'D' => ['', without_reason] }

    DESCRIBED_CLASS.stub(:all_value_directives, test_values) do
      DESCRIBED_CLASS.stub(:deprecated_klass, OpenStruct) do
        result = DESCRIBED_CLASS.all_deprecated_values

        assert_kind_of(Hash, result)
        assert_includes(result.keys, 'C')
        assert_includes(result.keys, 'D')
        assert_equal('sample', result['C'])
        assert_nil(result['D'])
      end
    end
  end

  def test_all_directives
    test_class_1 = Class.new(Rails::GraphQL::Type::Enum)
    test_class_1.stub(:all_value_directives, { 'A' => Set[1, 2] }) do
      result = test_class_1.all_directives
      assert_kind_of(Set, result)
      assert_equal([1, 2], result.to_a)
    end
  end

  def test_inspect
    DESCRIBED_CLASS.stub(:name, 'GraphQL::TestEnum') do
      DESCRIBED_CLASS.stub(:all_values, %w[]) do
        assert_equal('#<GraphQL::Enum Test (0) {}>', DESCRIBED_CLASS.inspect)
      end

      DESCRIBED_CLASS.stub(:all_values, %w[A B C]) do
        assert_equal('#<GraphQL::Enum Test (3) {A | B | C}>', DESCRIBED_CLASS.inspect)
      end
    end
  end

  def test_to_sym
    assert_raises(StandardError) { DESCRIBED_CLASS.new(nil).to_sym }
    assert_raises(StandardError) { DESCRIBED_CLASS.new(1).to_sym }
    assert_equal(:abc, DESCRIBED_CLASS.new('ABC').to_sym)
  end

  def test_to_i
    assert_nil(DESCRIBED_CLASS.new(nil).to_i)
    assert_nil(DESCRIBED_CLASS.new('abc').to_i)
    DESCRIBED_CLASS.stub(:all_values, %w[A B C]) do
      assert_equal(1, DESCRIBED_CLASS.new('B').to_i)
    end
  end

  def test_valid_ask
    assert(DESCRIBED_CLASS.new('A').valid?)
    refute(DESCRIBED_CLASS.new(nil).valid?)
    refute(DESCRIBED_CLASS.new('ABC').valid?)
  end

  def test_description
    DESCRIBED_CLASS.stub(:all_value_description, { 'A' => 'test' }) do
      assert_nil(DESCRIBED_CLASS.new(1).description)
      assert_nil(DESCRIBED_CLASS.new(nil).description)
      assert_equal('test', DESCRIBED_CLASS.new('A').description)
    end
  end

  def test_directives
    DESCRIBED_CLASS.stub(:all_value_directives, { 'A' => 'test' }) do
      assert_nil(DESCRIBED_CLASS.new(1).directives)
      assert_nil(DESCRIBED_CLASS.new(nil).directives)
      assert_equal('test', DESCRIBED_CLASS.new('A').directives)
    end
  end

  def test_deprecated_ask
    DESCRIBED_CLASS.stub(:all_deprecated_values, { 'A' => 'test' }) do
      assert(DESCRIBED_CLASS.new('A').deprecated?)
      refute(DESCRIBED_CLASS.new(nil).deprecated?)
      refute(DESCRIBED_CLASS.new(1).deprecated?)
    end
  end

  def test_deprecated_reason
    obj = DESCRIBED_CLASS.new('A')
    obj.stub(:deprecated_directive, double(args: double(reason: 'sample'))) do
      assert_equal('sample', obj.deprecated_reason)
    end
  end
end
