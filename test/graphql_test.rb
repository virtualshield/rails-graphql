require 'config'

class GraphQLTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL

  def test_type_map
    DESCRIBED_CLASS.stub_cvar(:@@type_map, 1) do
      assert_equal(1, DESCRIBED_CLASS.type_map)
    end

    assert_instance_of(Rails::GraphQL::TypeMap, DESCRIBED_CLASS.type_map)
  end

  def test_ar_adapter_key
    DESCRIBED_CLASS.stub(:config, double(ar_adapters: { 'a' => 1 })) do
      assert_equal(1, DESCRIBED_CLASS.ar_adapter_key('a'))
      assert_nil(DESCRIBED_CLASS.ar_adapter_key('b'))
    end
  end

  def test_enable_ar_adapter
    DESCRIBED_CLASS.stub_cvar(:@@loaded_adapters, Set[1]) do
      DESCRIBED_CLASS.enable_ar_adapter(1)
      pass 'Accepted any value set on loaded_adapters'
    end

    value = DESCRIBED_CLASS.get_reset_cvar(:@@loaded_adapters) do
      DESCRIBED_CLASS.enable_ar_adapter('PostgreSQL')
    end

    assert_includes(value, 'PostgreSQL')
  end

  def test_reload_ar_adapters_bang
    result = []
    DESCRIBED_CLASS.stub(:enable_ar_adapter, ->(x) { result << x }) do
      DESCRIBED_CLASS.reload_ar_adapters!
      assert_empty(result)

      DESCRIBED_CLASS.stub_cvar(:@@loaded_adapters, Set[1]) do
        DESCRIBED_CLASS.reload_ar_adapters!
        assert_equal([1], result)
      end
    end
  end

  def test_to_gql
    DESCRIBED_CLASS.stub_const(:ToGQL, double(compile: passallthrough)) do
      assert_equal([1], DESCRIBED_CLASS.to_gql(1))
      assert_equal([1, {a: 1}], DESCRIBED_CLASS.to_gql(1, a: 1))
    end
  end
end
