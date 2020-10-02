require 'config'

class InterfaceTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Type::Interface)

  def test_all_types
    assert_instance_of(Set, DESCRIBED_CLASS.all_types)

    DESCRIBED_CLASS.types << :a
    assert_equal(Set[:a], DESCRIBED_CLASS.all_types)

    other_class = Class.new(DESCRIBED_CLASS)
    other_class.types << :b
    assert_equal(Set[:a, :b], other_class.all_types)

    DESCRIBED_CLASS.instance_variable_set(:@types, Set.new)
  end

  def test_equivalence
    test_object = double(object?: true, implements?: ->(*) { true })
    assert(DESCRIBED_CLASS =~ test_object)

    test_object = double(object?: false, implements?: ->(*) { true })
    refute(DESCRIBED_CLASS =~ test_object)

    test_object = double(object?: true, implements?: ->(*) { false })
    refute(DESCRIBED_CLASS =~ test_object)

    test_object = double(object?: false, implements?: ->(*) { false })
    refute(DESCRIBED_CLASS =~ test_object)
  end

  def test_implemented
    DESCRIBED_CLASS.stub(:gql_name, 'test') do
      DESCRIBED_CLASS.stub(:fields, {}) do
        object = double(gql_name: 'baz', field?: ->(*) { false }, proxy_field: -> {})
        assert_equal(Set[object], implemented_types(object))
      end

      DESCRIBED_CLASS.stub(:fields, { 'a' => 'b' }) do
        object = double(gql_name: 'baz', field?: ->(*) { true }, fields: { 'a' => /b/ })
        assert_equal(Set[object], implemented_types(object))
      end

      fields = { 'a' => double(gql_name: 'a') }
      DESCRIBED_CLASS.stub(:fields, fields) do
        object = double(gql_name: 'baz', field?: ->(*) { true }, fields: { 'a' => 'b' })
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
    DESCRIBED_CLASS.get_reset_ivar(:@types) do
      DESCRIBED_CLASS.implemented(object)
    end
  end
end
