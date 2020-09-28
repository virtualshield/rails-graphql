require 'config'

GraphQL::TestObject = Class.new(Rails::GraphQL::Type::Object)

FIELDS = {
  name: OpenStruct.new(method_name: :name),
  age:  OpenStruct.new(method_name: :age),
}

class ObjectTest < GraphQL::TestCase
  def test_valid_member_ask
    GraphQL::TestObject.stub(:fields, FIELDS) do
      value = { name: '' }
      refute(GraphQL::TestObject.valid_member?(value))

      value = { name: '', age: 0 }
      assert(GraphQL::TestObject.valid_member?(value))

      value = { name: '', age: 0, email: '' }
      assert(GraphQL::TestObject.valid_member?(value))

      value = { 'name' => '', 'age' => 0 }
      assert(GraphQL::TestObject.valid_member?(value))

      value = OpenStruct.new(name: '',  age: 0)
      assert(GraphQL::TestObject.valid_member?(value))
    end
  end

  def test_equivalence
    GraphQL::TestObject.stub(:implements?, true) do
      assert(GraphQL::TestObject =~ OpenStruct.new(interface?: true))
      refute(GraphQL::TestObject =~ OpenStruct.new(interface?: false))
    end

    GraphQL::TestObject.stub(:implements?, false) do
      refute(GraphQL::TestObject =~ OpenStruct.new(interface?: true))
      refute(GraphQL::TestObject =~ OpenStruct.new(interface?: false))
    end
  end

  MockedInterface = Class.new { def implemented(*); end }
  def test_implements
    assert_nil(GraphQL::TestObject.implements)

    foo = MockedInterface.new
    baz = MockedInterface.new
    check_interfaces([foo])     { GraphQL::TestObject.implements(foo) }
    check_interfaces([foo])     { GraphQL::TestObject.implements(foo, foo) }
    check_interfaces([], [foo]) { GraphQL::TestObject.implements(foo) }
    check_interfaces([foo, baz]) { GraphQL::TestObject.implements(foo, baz) }
    check_interfaces([], [foo, baz]) { GraphQL::TestObject.implements(foo, baz) }
    check_interfaces([baz], [foo]) { GraphQL::TestObject.implements(baz) }
    check_interfaces([baz], [foo]) { GraphQL::TestObject.implements(foo, baz) }
  end

  PASSTHROUGH = ->(x) { x }
  def check_interfaces(result, cache = [], &block)
    GraphQL::TestObject.stub(:find_interface!, PASSTHROUGH) do
      GraphQL::TestObject.stub(:all_interfaces, cache, &block)
      assert_equal(result, GraphQL::TestObject.interfaces.to_a)
      GraphQL::TestObject.instance_variable_set(:@interfaces, [])
    end
  end

  def test_implements_ask
    GraphQL::TestObject.stub(:find_interface!, PASSTHROUGH) do
      GraphQL::TestObject.stub(:all_interfaces, [1]) do
        assert(GraphQL::TestObject.implements?(1))
        refute(GraphQL::TestObject.implements?(nil))
      end
      GraphQL::TestObject.stub(:all_interfaces, []) do
        refute(GraphQL::TestObject.implements?(1))
      end
    end
  end

  def test_find_interface
    raise_block = ->(x) { raise }
    GraphQL::TestObject.stub(:find_interface!, PASSTHROUGH) do
      assert_equal(1, GraphQL::TestObject.send(:find_interface, 1))
    end
    GraphQL::TestObject.stub(:find_interface!, raise_block) do
      assert_raises(StandardError) { GraphQL::TestObject.send(:find_interface, 1) }
    end
  end

  def test_find_interface!
  # TODO
  end
end
