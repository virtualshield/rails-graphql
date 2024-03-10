require 'config'

class GraphQL_TypeTest < GraphQL::TestCase
  class DESCRIBED_CLASS < Rails::GraphQL::Type; end

  def test_inherited
    assert_equal(DESCRIBED_CLASS, DESCRIBED_CLASS.base_type)
    assert_predicate(DESCRIBED_CLASS, :described_class?)
    assert_predicate(DESCRIBED_CLASS, :spec_object?)
    assert_predicate(DESCRIBED_CLASS, :base_object?)
    assert_predicate(DESCRIBED_CLASS, :abstract?)

    other_class = unmapped_class(DESCRIBED_CLASS)
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

  def test_kind_ask
    assert_respond_to(DESCRIBED_CLASS, :scalar?)
    assert_respond_to(DESCRIBED_CLASS, :object?)
    assert_respond_to(DESCRIBED_CLASS, :interface?)
    assert_respond_to(DESCRIBED_CLASS, :union?)
    assert_respond_to(DESCRIBED_CLASS, :enum?)
    assert_respond_to(DESCRIBED_CLASS, :input?)
  end

  def test_normalize_type
    # Simple string and symbol
    assert_equal(:string, DESCRIBED_CLASS.normalize_type(:name, :string, {}))
    assert_equal('String', DESCRIBED_CLASS.normalize_type(:name, 'String', {}))

    # Not provided type
    assert_equal('ID', DESCRIBED_CLASS.normalize_type(:id, nil, {}))
    assert_equal('ID', DESCRIBED_CLASS.normalize_type('id', nil, {}))
    assert_equal('String', DESCRIBED_CLASS.normalize_type(:name, nil, {}))

    # Typed class and any other class
    string = GraphQL::Scalar::StringScalar
    assert_equal(['String', string], DESCRIBED_CLASS.normalize_type(:name, string, {}))

    other = Class.new
    assert_equal(other, DESCRIBED_CLASS.normalize_type(:name, other, {}))

    # Direct token
    xargs = {}
    token = GQLParser.parse_type('[String!]!')
    assert_equal('String', DESCRIBED_CLASS.normalize_type(:name, token, xargs))
    assert_equal({ array: true, nullable: false, null: false }, xargs)

    # String that can be parsed into token
    xargs = {}
    assert_equal('String', DESCRIBED_CLASS.normalize_type(:name, '[String!]!', xargs))
    assert_equal({ array: true, nullable: false, null: false }, xargs)
  end
end
