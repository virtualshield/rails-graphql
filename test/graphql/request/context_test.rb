require 'config'

class ContextTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Request::Context)

  def test_stacked
    object = DESCRIBED_CLASS.new
    object.stacked('a') do
      object.stacked('b') do
        object.stacked('c') do
          object.stacked('d') do
            assert_equal('c', object.parent)
            assert(object.override_value('e'))
            assert_equal('e', object.current_value)
            assert_equal(['c', 'b', 'a'], object.ancestors)
          end
        end
      end
    end

    object.stacked('a') do |value|
      assert_equal('a', object.current_value)
      assert_equal('a', value)

      object.current_value = 'b'
      assert_equal('b', object.current_value)
      assert_equal('b', value)

      object.stacked('c') do
        assert_equal('c', object.current_value)
        assert_equal('c', value)

        object.current_value = 'e'
        assert_equal('e', object.current_value)
        assert_equal('e', value)
      end

      assert_equal('b', object.current_value)
      assert_equal('b', value)
    end
  end

  def test_parent
    object = DESCRIBED_CLASS.new
    object.stub_ivar(:@stack, ['a','b']) do
      assert_equal('b', object.parent)
    end
  end

  def test_ancestors
    object = DESCRIBED_CLASS.new
    object.stub_ivar(:@stack, ['a', 'b', 'c']) do
      assert_equal(['b', 'c'], object.ancestors)
    end
  end

  def test_current_value
    object = DESCRIBED_CLASS.new
    object.stub_ivar(:@stack, ['b']) do
      assert_equal('b', object.current_value)
    end
  end

  def test_override_value
    object = DESCRIBED_CLASS.new
    object.stub_ivar(:@stack, ['b']) do
      assert_equal('c', object.override_value('c'))
    end
  end
end