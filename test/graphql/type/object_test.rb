require 'config'

class GraphQL_Type_ObjectTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Type::Object)

  def test_valid_member_ask
    fields = {
      name: double(method_name: :name),
      age:  double(method_name: :age),
    }

    DESCRIBED_CLASS.stub(:fields, fields) do
      value = { name: '' }
      refute(DESCRIBED_CLASS.valid_member?(value))

      value = { name: '', age: 0 }
      assert(DESCRIBED_CLASS.valid_member?(value))

      value = { name: '', age: 0, email: '' }
      assert(DESCRIBED_CLASS.valid_member?(value))

      value = { 'name' => '', 'age' => 0 }
      assert(DESCRIBED_CLASS.valid_member?(value))

      value = double(name: '',  age: 0)
      assert(DESCRIBED_CLASS.valid_member?(value))
    end
  end

  def test_equivalence
    DESCRIBED_CLASS.stub(:implements?, true) do
      assert_operator(DESCRIBED_CLASS, :=~, double(interface?: true))
      refute_operator(DESCRIBED_CLASS, :=~, double(interface?: false))
    end

    DESCRIBED_CLASS.stub(:implements?, false) do
      refute_operator(DESCRIBED_CLASS, :=~, double(interface?: true))
      refute_operator(DESCRIBED_CLASS, :=~, double(interface?: false))
    end
  end

  def test_implements
    assert_nil(DESCRIBED_CLASS.implements)

    foo = double(implemented: ->(*) {})
    baz = double(implemented: ->(*) {})

    check_interfaces([foo])          { DESCRIBED_CLASS.implements(foo) }
    check_interfaces([foo])          { DESCRIBED_CLASS.implements(foo, foo) }
    check_interfaces([], [foo])      { DESCRIBED_CLASS.implements(foo) }
    check_interfaces([foo, baz])     { DESCRIBED_CLASS.implements(foo, baz) }
    check_interfaces([], [foo, baz]) { DESCRIBED_CLASS.implements(foo, baz) }
    check_interfaces([baz], [foo])   { DESCRIBED_CLASS.implements(baz) }
    check_interfaces([baz], [foo])   { DESCRIBED_CLASS.implements(foo, baz) }
  end

  def test_implements_ask
    DESCRIBED_CLASS.stub(:find_interface!, passthrough) do
      DESCRIBED_CLASS.stub(:all_interfaces, [1]) do
        assert(DESCRIBED_CLASS.implements?(1))
        refute(DESCRIBED_CLASS.implements?(nil))
      end


      DESCRIBED_CLASS.stub(:all_interfaces, []) do
        refute(DESCRIBED_CLASS.implements?(1))
      end
    end
  end

  def test_find_interface
    DESCRIBED_CLASS.stub(:find_interface!, passthrough) do
      assert_equal(1, DESCRIBED_CLASS.send(:find_interface, 1))
    end

    raise_block = ->(x) { raise }
    DESCRIBED_CLASS.stub(:find_interface!, raise_block) do
      assert_raises(StandardError) { DESCRIBED_CLASS.send(:find_interface, 1) }
    end
  end

  def test_find_interface_bang
    assert_raises(StandardError) { DESCRIBED_CLASS.send(:find_interface!, 1) }

    fake_interface = Class.new(Rails::GraphQL::Type::Interface)
    assert_equal(fake_interface, DESCRIBED_CLASS.send(:find_interface!, fake_interface))

    stubbed_type_map do
      fake_interface = double(Module.new, interface?: true)
      assert_equal(fake_interface, DESCRIBED_CLASS.send(:find_interface!, fake_interface))

      fake_interface = double(interface?: true)
      assert_equal(fake_interface, DESCRIBED_CLASS.send(:find_interface!, fake_interface))
    end
  end

  def check_interfaces(result, cache = [], &block)
    DESCRIBED_CLASS.stub(:find_interface!, passthrough) do
      DESCRIBED_CLASS.stub(:all_interfaces, cache, &block)
      assert_equal(result, DESCRIBED_CLASS.interfaces.to_a)
      DESCRIBED_CLASS.remove_instance_variable(:@interfaces)
    end
  end
end
