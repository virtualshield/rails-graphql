require 'config'

GraphQL::TestObject = Class.new(Rails::GraphQL::Type::Interface)

class InterfaceTest < GraphQL::TestCase
  def test_all_types
    assert_equal([], GraphQL::TestObject.all_types.to_a)

    GraphQL::TestObject.types << :a
    assert_equal([:a], GraphQL::TestObject.all_types.to_a)

    other_class = Class.new(GraphQL::TestObject)
    other_class.types << :b
    assert_equal([:a, :b], other_class.all_types.to_a)

    GraphQL::TestObject.instance_variable_set(:@types, Set.new)
  end


  def test_equivalence
    test_object = OpenStruct.new(object?: true)
    test_object.define_singleton_method(:implements?) { |*| true }
    assert(GraphQL::TestObject =~ test_object)
    test_object[:object?] = false
    refute(GraphQL::TestObject =~ test_object)

    test_object.define_singleton_method(:implements?) { |*| false }
    refute(GraphQL::TestObject =~ test_object)
    test_object[:object?] = true
    refute(GraphQL::TestObject =~ test_object)
  end

  def test_implemented
    GraphQL::TestObject.stub(:gql_name, 'test') do
      GraphQL::TestObject.stub(:fields, {}) do
        object = OpenStruct.new(gql_name: 'baz')
        object.define_singleton_method(:field?) { |*| false }
        object.define_singleton_method(:proxy_field) { |*| }
        result = check_types { GraphQL::TestObject.implemented(object) }
        assert_equal([object], result)
      end

      GraphQL::TestObject.stub(:fields, { 'a' => 'b' }) do
        object = OpenStruct.new(gql_name: 'baz', fields: { 'a' => /b/ })
        object.define_singleton_method(:field?) { |*| true }
        result = check_types { GraphQL::TestObject.implemented(object) }
        assert_equal([object], result)
      end

      fields = { 'a' => OpenStruct.new(gql_name: 'a') }
      GraphQL::TestObject.stub(:fields, fields) do
        object = OpenStruct.new(gql_name: 'baz', fields: { 'a' => 'b' })
        object.define_singleton_method(:field?) { |*| true }
        assert_raises(StandardError) { GraphQL::TestObject.implemented(object) }
      end
    end
  end

  def check_types
    yield
    result = GraphQL::TestObject.instance_variable_get(:@types)
    GraphQL::TestObject.instance_variable_set(:@types, Set.new)
    result.to_a
  end

  # def inspect
  # end
end