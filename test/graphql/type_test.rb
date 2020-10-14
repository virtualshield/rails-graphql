require 'config'

class GraphQL_TypeTest < GraphQL::TestCase
  class DESCRIBED_CLASS < Rails::GraphQL::Type; end

  def test_inherited
    assert_equal(DESCRIBED_CLASS, DESCRIBED_CLASS.base_type)
    assert_predicate(DESCRIBED_CLASS, :described_class?)
    assert_predicate(DESCRIBED_CLASS, :spec_object?)
    assert_predicate(DESCRIBED_CLASS, :base_object?)
    assert_predicate(DESCRIBED_CLASS, :abstract?)

    other_class = Class.new(DESCRIBED_CLASS)
    assert_equal(DESCRIBED_CLASS, other_class.base_type)
    assert_predicate(other_class, :described_class?)
    refute_predicate(other_class, :spec_object?)
    refute_predicate(other_class, :base_object?)
    refute_predicate(other_class, :abstract?)
  end

  def test_equivalence
    assert_operator(Rails::GraphQL::Type, :=~, DESCRIBED_CLASS)
    assert_operator(Rails::GraphQL::Type, :=~, DESCRIBED_CLASS.new)
    assert_operator(DESCRIBED_CLASS, :=~, DESCRIBED_CLASS.new)

    refute_operator(Rails::GraphQL::Type::Scalar, :=~, DESCRIBED_CLASS)
  end

  def test_kind
    assert_equal(:described_class, DESCRIBED_CLASS.kind)
  end

  def test_kind_enum
    assert_equal('DESCRIBED_CLASS', DESCRIBED_CLASS.kind_enum)
  end

  def test_decorate
    assert_equal(1, DESCRIBED_CLASS.decorate(1))
  end

  def test_gql_resolver_ask
    DESCRIBED_CLASS.stub(:base_object?, false) do
      refute(DESCRIBED_CLASS.gql_resolver?(:calculate))
      DESCRIBED_CLASS.send(:define_method, :calculate) {}

      assert(DESCRIBED_CLASS.gql_resolver?(:calculate))

      other_class = Class.new(DESCRIBED_CLASS)
      assert(other_class.gql_resolver?(:calculate))

      other_class.stub(:base_object?, true) do
        refute(other_class.gql_resolver?(:calculate))
      end

      DESCRIBED_CLASS.send(:undef_method, :calculate)
      refute(DESCRIBED_CLASS.gql_resolver?(:calculate))
    end
  end

  def test_kind_ask
    assert_respond_to(DESCRIBED_CLASS, :scalar?)
    assert_respond_to(DESCRIBED_CLASS, :object?)
    assert_respond_to(DESCRIBED_CLASS, :interface?)
    assert_respond_to(DESCRIBED_CLASS, :union?)
    assert_respond_to(DESCRIBED_CLASS, :enum?)
    assert_respond_to(DESCRIBED_CLASS, :input?)
  end
end
