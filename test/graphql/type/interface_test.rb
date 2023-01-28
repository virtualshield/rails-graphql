require 'config'

class GraphQL_Type_InterfaceTest < GraphQL::TestCase
  DESCRIBED_CLASS = unmapped_class(Rails::GraphQL::Type::Interface)

  def test_all_types
    assert_nil(DESCRIBED_CLASS.all_types)

    DESCRIBED_CLASS.types << :a
    assert_equal([:a], DESCRIBED_CLASS.all_types.to_a)

    other_class = unmapped_class(DESCRIBED_CLASS)
    other_class.types << :b
    assert_equal([:a, :b], other_class.all_types.to_a)

    DESCRIBED_CLASS.instance_variable_set(:@types, nil)
  end

  def test_equivalence
    test_object = double(object?: true, implements?: ->(*) { true })
    assert_operator(DESCRIBED_CLASS, :=~, test_object)

    test_object = double(object?: false, implements?: ->(*) { true })
    refute_operator(DESCRIBED_CLASS, :=~, test_object)

    test_object = double(object?: true, implements?: ->(*) { false })
    refute_operator(DESCRIBED_CLASS, :=~, test_object)

    test_object = double(object?: false, implements?: ->(*) { false })
    refute_operator(DESCRIBED_CLASS, :=~, test_object)
  end

  def test_implemented
    skip 'Needs better double of interface'
    DESCRIBED_CLASS.stub(:gql_name, 'test') do
      DESCRIBED_CLASS.stub(:fields, {}) do
        object = double(gql_name: 'baz', has_field?: ->(*) { false }, proxy_field: -> {})
        assert_equal(Set[object], implemented_types(object))
      end

      field = double(name: 'a', :"=~" => ->(*) { true })
      DESCRIBED_CLASS.stub(:fields, { 'a' => field }) do
        object = double(gql_name: 'baz', has_field?: ->(*) { true }, fields: { 'a' => field })
        assert_equal(Set[object], implemented_types(object))
      end

      field = double(name: 'a', :"=~" => ->(*) { false })
      fields = { 'a' => field }
      DESCRIBED_CLASS.stub(:fields, fields) do
        object = double(gql_name: 'baz', has_field?: ->(*) { true }, fields: { 'a' => field })
        assert_raises(StandardError) { DESCRIBED_CLASS.implemented(object) }
      end
    end
  end

  def test_inspect
    DESCRIBED_CLASS.stub(:gql_name, 'foo') do
      DESCRIBED_CLASS.stub_ivar(:@fields, {}) do
        assert_equal('#<GraphQL::Interface foo>', DESCRIBED_CLASS.inspect)
      end

      DESCRIBED_CLASS.stub_ivar(:@fields, { 'a' => 'a' }) do
        assert_equal('#<GraphQL::Interface foo {"a"}>', DESCRIBED_CLASS.inspect)
      end

      DESCRIBED_CLASS.stub_ivar(:@fields, { 'a' => 'a', 'b' => 'b' }) do
        assert_equal('#<GraphQL::Interface foo {"a", "b"}>', DESCRIBED_CLASS.inspect)
      end
    end
  end

  def implemented_types(object)
    DESCRIBED_CLASS.get_reset_ivar(:@types) { implemented(object) }
  end
end
