require 'config'

class GraphQL_Type_EnumTest < GraphQL::TestCase
  DESCRIBED_CLASS = unmapped_class(Rails::GraphQL::Type::Enum)
  %w[A B C].each(&DESCRIBED_CLASS.method(:add))

  def test_indexed
    refute_predicate(DESCRIBED_CLASS, :indexed?)
    DESCRIBED_CLASS.indexed!
    assert_predicate(DESCRIBED_CLASS, :indexed?)
    DESCRIBED_CLASS.remove_instance_variable(:@indexed)
  end

  def test_valid_input_ask
    assert(DESCRIBED_CLASS.valid_input?('A'))

    refute(DESCRIBED_CLASS.valid_input?(1))
    refute(DESCRIBED_CLASS.valid_input?(nil))
    refute(DESCRIBED_CLASS.valid_input?('abc'))

    str_token = new_token('"A"', :string)
    refute(DESCRIBED_CLASS.valid_input?(str_token))

    stubbed_config(:allow_string_as_enum_input, true) do
      assert(DESCRIBED_CLASS.valid_input?(str_token))
    end
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
    sample_class = unmapped_class(Rails::GraphQL::Type::Enum)
    %w[A B C].each(&sample_class.method(:add))

    assert_nil(sample_class.as_json(nil))

    test_value = sample_class.new('A')
    assert_equal('A', sample_class.as_json(test_value))

    sample_class.stub(:indexed?, true) do
      assert_equal('B', sample_class.as_json(1))
    end

    sample_class.stub(:indexed?, false) do
      assert_equal('1', sample_class.as_json(1))
    end

    assert_equal('ABC', sample_class.as_json('abc'))
  end

  def test_deserialize
    assert_nil(DESCRIBED_CLASS.deserialize(nil))
    assert_nil(DESCRIBED_CLASS.deserialize('X'))

    test_value = DESCRIBED_CLASS.deserialize('A')
    assert_instance_of(DESCRIBED_CLASS, test_value)
    assert_equal('A', test_value.value)

    str_token = new_token('"A"', :string)
    assert_nil(DESCRIBED_CLASS.deserialize(str_token))
    stubbed_config(:allow_string_as_enum_input, true) do
      test_value = DESCRIBED_CLASS.deserialize(str_token)
      assert_instance_of(DESCRIBED_CLASS, test_value)
      assert_equal('A', test_value.value)
    end
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
    assert_raises(StandardError) { DESCRIBED_CLASS.add('') }

    DESCRIBED_CLASS.stub(:all_values, %w[A B C]) do
      assert_raises(StandardError) { DESCRIBED_CLASS.add('A') }

      DESCRIBED_CLASS.add('D')
      assert_includes(DESCRIBED_CLASS.values, 'D')
      refute_includes(DESCRIBED_CLASS.value_directives.keys, 'D')
      refute_includes(DESCRIBED_CLASS.value_description.keys, 'D')

      DESCRIBED_CLASS.add('D', desc: 'Just D')
      assert_includes(DESCRIBED_CLASS.value_description.keys, 'D')
      assert_equal('Just D', DESCRIBED_CLASS.value_description['D'])

      stubbed_directives_to_set do
        DESCRIBED_CLASS.add('D', deprecated: 'done')
        directives = DESCRIBED_CLASS.value_directives['D']
        assert_equal(1, directives.size)
        assert_instance_of(deprecated_directive, directives[0])
        assert_equal('done', directives[0].args.reason)

        DESCRIBED_CLASS.add('D', directives: 'other', deprecated: true)
        directives = DESCRIBED_CLASS.value_directives['D']
        assert_equal(2, directives.size)
        assert_equal('other', directives[0])
        assert_instance_of(deprecated_directive, directives[1])
      end
    end
  end

  def test_value_using_ask
    assert_raises(StandardError) { DESCRIBED_CLASS.value_using?(nil, DESCRIBED_CLASS) }

    test_directive    = unmapped_class(Rails::GraphQL::Directive)
    missing_directive = unmapped_class(Rails::GraphQL::Directive)
    test_values = { 'B' => [], 'C' => [test_directive.new] }

    DESCRIBED_CLASS.stub(:as_json, passthrough) do
      DESCRIBED_CLASS.stub(:all_value_directives, test_values) do
        refute(DESCRIBED_CLASS.value_using?('A', test_directive))
        refute(DESCRIBED_CLASS.value_using?('B', test_directive))
        refute(DESCRIBED_CLASS.value_using?('C', missing_directive))

        assert(DESCRIBED_CLASS.value_using?('C', test_directive))
      end
    end
  end

  def test_all_deprecated_values
    with_reaons = deprecated_directive.new(reason: 'sample')
    without_reason = deprecated_directive.new(reason: nil)
    test_values = { 'A' => [], 'B' => [''], 'C' => [with_reaons], 'D' => ['', without_reason] }

    DESCRIBED_CLASS.stub(:all_value_directives, test_values) do
      result = DESCRIBED_CLASS.all_deprecated_values

      assert_kind_of(Hash, result)
      assert_includes(result.keys, 'C')
      assert_includes(result.keys, 'D')
      assert_equal('sample', result['C'])
      assert(result['D'])
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
    test_directive = unmapped_class(deprecated_directive).new
    DESCRIBED_CLASS.stub(:all_value_directives, { 'A' => [test_directive] }) do
      assert(DESCRIBED_CLASS.new('A').deprecated?)
      refute(DESCRIBED_CLASS.new(nil).deprecated?)
      refute(DESCRIBED_CLASS.new(1).deprecated?)
    end
  end

  def test_deprecated_reason
    obj = DESCRIBED_CLASS.new('A')
    dir = double(args: double(reason: 'sample'), is_a?: ->(*) { true })
    obj.stub(:deprecated?, true) do
      obj.stub(:directives, [dir]) do
        assert_equal('sample', obj.deprecated_reason)
      end
    end
  end

  def deprecated_directive
    Rails::GraphQL::Directive::DeprecatedDirective
  end
end
