require 'config'

class GraphQL_SchemaTest < GraphQL::TestCase
  DESCRIBED_CLASS = unmapped_class(Rails::GraphQL::Schema)

  def test_gql_name
    assert_equal('__Schema', DESCRIBED_CLASS.gql_name)
    assert_equal('__Schema', DESCRIBED_CLASS.graphql_name)
  end

  def test_kind
    assert_equal(:schema, DESCRIBED_CLASS.kind)
  end

  def test_find
    DESCRIBED_CLASS.stub(:type_map, double(fetch: passallthrough)) do
      settings = { namespaces: 1, base_class: :Schema, exclusive: true }
      assert_equal([:schema, settings], DESCRIBED_CLASS.find(1))
    end
  end

  def test_find_bang
    DESCRIBED_CLASS.stub(:type_map, double(fetch!: passallthrough)) do
      settings = { namespaces: 1, base_class: :Schema, exclusive: true }
      assert_equal([:schema, settings], DESCRIBED_CLASS.find!(1))
    end
  end

  def test_types
    DESCRIBED_CLASS.stub(:type_map, double(each_from: passallthrough)) do
      DESCRIBED_CLASS.stub(:namespace, 1) do
        assert_equal([1, { base_class: :Type }], DESCRIBED_CLASS.types)
        assert_equal([1, { base_class: 2 }], DESCRIBED_CLASS.types(base_class: 2))
      end
    end
  end

  def test_set_namespace
    result = DESCRIBED_CLASS.get_reset_ivar(:@namespace) { set_namespace('a') }
    assert_equal(:a, result)

    result = DESCRIBED_CLASS.get_reset_ivar(:@namespace) { set_namespace('b', 'c') }
    assert_equal(:b, result)
  end

  def test_namespace
    assert_equal(:base, DESCRIBED_CLASS.namespace)

    DESCRIBED_CLASS.stub_ivar(:@namespace, nil) do
      assert_equal(:base, DESCRIBED_CLASS.namespace)
    end

    DESCRIBED_CLASS.stub_ivar(:@namespace, 1) do
      assert_equal(1, DESCRIBED_CLASS.namespace)
    end

    DESCRIBED_CLASS.stub(:set_namespace, passthrough) do
      assert_equal(1, DESCRIBED_CLASS.namespace(1))
      assert_equal(2, DESCRIBED_CLASS.namespace(2, 3))
    end
  end

  def test_registered_ask
    DESCRIBED_CLASS.stub(:type_map, double(object_exist?: passallthrough)) do
      assert_equal([DESCRIBED_CLASS, { exclusive: true }], DESCRIBED_CLASS.registered?)
    end
  end

  def test_find_type
    DESCRIBED_CLASS.stub(:namespaces, :a) do
      DESCRIBED_CLASS.stub(:type_map, double(fetch: passallthrough)) do
        settings = { base_class: :Type, namespaces: :a }
        assert_equal([1, settings], DESCRIBED_CLASS.find_type(1))

        settings.merge!(other: 2)
        assert_equal([1, settings], DESCRIBED_CLASS.find_type(1, other: 2))
      end
    end
  end

  def test_find_type_bang
    DESCRIBED_CLASS.stub(:namespaces, :a) do
      DESCRIBED_CLASS.stub(:type_map, double(fetch!: passallthrough)) do
        settings = { base_class: :Type, namespaces: :a }
        assert_equal([1, settings], DESCRIBED_CLASS.find_type!(1))

        settings.merge!(other: 2)
        assert_equal([1, settings], DESCRIBED_CLASS.find_type!(1, other: 2))
      end
    end
  end

  def test_find_directive_bang
    DESCRIBED_CLASS.stub(:namespaces, :a) do
      DESCRIBED_CLASS.stub(:type_map, double(fetch!: passallthrough)) do
        settings = { base_class: :Directive, namespaces: :a }
        assert_equal([1, settings], DESCRIBED_CLASS.find_directive!(1))

        settings.merge!(other: 2)
        assert_equal([1, settings], DESCRIBED_CLASS.find_directive!(1, other: 2))
      end
    end
  end

  def test_to_gql
    Rails::GraphQL.stub_const(:ToGQL, double(describe: passallthrough)) do
      assert_equal([DESCRIBED_CLASS], DESCRIBED_CLASS.to_gql)
      assert_equal([DESCRIBED_CLASS, { other: 1 }], DESCRIBED_CLASS.to_gql(other: 1))
    end
  end

  def test_kinds
    DESCRIBED_CLASS.stub(:create_type, passallthrough) do
      assert_equal([:some, :Enum],      DESCRIBED_CLASS.send(:enum,      :some))
      assert_equal([:some, :Input],     DESCRIBED_CLASS.send(:input,     :some))
      assert_equal([:some, :Interface], DESCRIBED_CLASS.send(:interface, :some))
      assert_equal([:some, :Object],    DESCRIBED_CLASS.send(:object,    :some))
      assert_equal([:some, :Scalar],    DESCRIBED_CLASS.send(:scalar,    :some))
      assert_equal([:some, :Union],     DESCRIBED_CLASS.send(:union,     :some))
    end
  end

  def test_sources
    result, passthrough = collect_all_through
    xargs = { build: true }
    DESCRIBED_CLASS.stub(:source, passthrough) do
      result.clear && DESCRIBED_CLASS.send(:sources, :a, of_type: 1)
      assert_equal([[:a, 1, xargs]], result)

      result.clear && DESCRIBED_CLASS.send(:sources, :a, :b, of_type: 1)
      assert_equal([[:a, 1, xargs], [:b, 1, xargs]], result)

      source_const.stub(:find_for!, 2) do
        result.clear && DESCRIBED_CLASS.send(:sources, %i[c d e])
        assert_equal([[:c, 2, xargs], [:d, 2, xargs], [:e, 2, xargs]], result)
      end
    end
  end

  protected

    def type_const
      ::Rails::GraphQL::Type
    end

    def source_const
      ::Rails::GraphQL::Source
    end

    def collect_all_through
      result = []
      [result, ->(*x) { result << x }]
    end
end
