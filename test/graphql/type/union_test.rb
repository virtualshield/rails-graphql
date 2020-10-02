require 'config'

class InterfaceTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Type::Union)

  def test_of_kind
    field = double(base_type: 'a')
    DESCRIBED_CLASS.stub(:members, [field]) do
      assert_equal('a', DESCRIBED_CLASS.of_kind)
    end
  end

  def test_equivalence
    test_object = 'a'
    DESCRIBED_CLASS.stub(:all_members, [/a/]) do
      assert(DESCRIBED_CLASS =~ test_object)
    end
    DESCRIBED_CLASS.stub(:all_members, []) do
      refute(DESCRIBED_CLASS =~ test_object)
    end
    DESCRIBED_CLASS.stub(:all_members, [/b/]) do
      refute(DESCRIBED_CLASS =~ test_object)
    end
  end

  def test_append
    assert_nil(DESCRIBED_CLASS.append)

    object = double(base_type: Rails::GraphQL::Type::Object)
    object2 = double(base_type: 'a')

    assert_raises(StandardError) { DESCRIBED_CLASS.append(object) }
    assert_raises(StandardError) { DESCRIBED_CLASS.append(object, object2) }

    result = DESCRIBED_CLASS.get_reset_ivar(:@members, [object]) { DESCRIBED_CLASS.append(object) }
    assert_equal([object, object] , result)

    stubbed_type_map(:fetch) do
      object = double(base_type: 'a', is_a?: -> (*) { true } )
      DESCRIBED_CLASS.stub(:members?, true) do
        result = DESCRIBED_CLASS.get_reset_ivar(:@members, [object]) { DESCRIBED_CLASS.append(object) }
        assert_equal([object, object] , result)
      end
    end
  end

  def test_validate_bang
    test_object = double(base_type: 'a')
    test_object2 = double(base_type: 'b')
    DESCRIBED_CLASS.stub(:all_members, [test_object]) do
      assert_nil( DESCRIBED_CLASS.validate! )
    end

    DESCRIBED_CLASS.stub(:all_members, [test_object, test_object]) do
      assert_nil( DESCRIBED_CLASS.validate! )
    end

    DESCRIBED_CLASS.stub(:all_members, []) do
      assert_raises(StandardError) { DESCRIBED_CLASS.validate! }
    end

    DESCRIBED_CLASS.stub(:all_members, [test_object, test_object2]) do
      assert_raises(StandardError) { DESCRIBED_CLASS.validate! }
    end
  end

  def test_inspect
    test_object = double(gql_name: 'a')
    test_object2 = double(gql_name: 'b')
    DESCRIBED_CLASS.stub(:gql_name, 'foo') do
      DESCRIBED_CLASS.stub(:all_members, [test_object]) do
        assert_equal('#<GraphQL::Union foo (1) {a}>', DESCRIBED_CLASS.inspect)
      end
      DESCRIBED_CLASS.stub(:all_members, [test_object, test_object2]) do
        assert_equal('#<GraphQL::Union foo (2) {a | b}>', DESCRIBED_CLASS.inspect)
      end
    end
  end

end