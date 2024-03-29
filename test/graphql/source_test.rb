require 'config'

class GraphQL_SourceTest < GraphQL::TestCase
  def after
    source_const.class_variable_set(:@@pending, {})
    @described_class = nil
  end

  def described_class
    @described_class ||= unmapped_class(Rails::GraphQL::Source).tap do |klass|
      def klass.name; 'DESCRIBED_CLASS'; end
    end
  end

  alias setup after
  alias teardown after

  def test_kind
    assert_equal(:source, described_class.kind)
  end

  def test_base_type_class
    assert_equal(:Type, described_class.base_type_class)
  end

  def test_base_name
    described_class.stub(:abstract?, false) do
      assert_equal('DESCRIBED_CLASS', described_class.base_name)
    end
  end

  def test_inherited
    skip
  end

  def test_find_for_bang
    described_class.stub(:find_for, passthrough) do
      assert_equal(1, described_class.find_for!(1))
    end

    described_class.stub(:find_for, false) do
      assert_raises(StandardError) { described_class.find_for!(double(name: 'A')) }
    end
  end

  def test_find_for
    base  = double(assigned_class: Object)
    one   = double(assigned_class: unmapped_class)
    other = double(assigned_class: unmapped_class(one.assigned_class))

    described_class.stub(:base_sources, [base, one, other]) do
      assert_equal(base,  described_class.find_for('Class'))
      assert_equal(one,   described_class.find_for(one.assigned_class))
      assert_equal(one,   described_class.find_for(unmapped_class(one.assigned_class)))
      assert_equal(other, described_class.find_for(unmapped_class(other.assigned_class)))
      assert_nil(described_class.find_for('BasicObject'))
    end
  end

  def test_built_ask
    skip
  end

  def test_attach_fields_bang
    skip
  end

  def test_find_type_bang
    described_class.stub(:namespaces, :a) do
      Rails::GraphQL.stub(:type_map, double(fetch!: passallthrough)) do
        settings = { base_class: :Type, namespaces: :a }
        assert_equal([1, settings], described_class.send(:find_type!, 1))

        settings.merge!(other: 2)
        assert_equal([1, settings], described_class.send(:find_type!, 1, other: 2))
      end
    end
  end

  def test_type_map_after_register
    described_class.stub(:namespaces, :a) do
      Rails::GraphQL.stub(:type_map, double(after_register: passallthrough)) do
        settings = { namespaces: :a }
        assert_equal([settings], described_class.send(:type_map_after_register))

        assert_equal([1, settings], described_class.send(:type_map_after_register, 1))

        settings.merge!(o: 2)
        assert_equal([1, settings], described_class.send(:type_map_after_register, 1, o: 2))
      end
    end
  end

  def test_create_enum
    skip
  end

  def test_skip_from
    hash_list = Hash.new { |h, k| h[k] = Set.new }
    described_class.stub(:segmented_skip_fields, -> { hash_list }) do
      assert_equal(Set[:a], described_class.send(:skip_from, 1, :a))
      assert_equal(Set[:b], described_class.send(:skip_from, 2, 'b'))
      assert_equal(Set[:b, :c, :d], described_class.send(:skip_from, 2, 'c', :d))
    end
  end

  def test_step
    skip
  end

  def test_skip
    assert_throws(:skip) do
      described_class.send(:skip, :start)

      assert_equal(1, described_class.hooks[:start].size)
      described_class.hooks[:start][0].call
    end
  end

  def test_override
    sequence = []
    described_class.stub(:skip, ->(*args) { sequence += args }) do
      described_class.stub(:step, ->(*args, &block) { sequence += args << block }) do
        described_class.send(:override, :start, &passthrough)
        assert_equal(0, described_class.hooks[:start].size)
        assert_equal([:start, :start, passthrough], sequence)
      end
    end
  end

  def test_disable
    described_class.stub(:hook_names, Set[:start]) do
      assert_includes(described_class.hook_names, :start)
      described_class.send(:disable, 'starts')
      refute_includes(described_class.hook_names, :start)
    end
  end

  def test_enable
    described_class.stub(:hook_names, Set[]) do
      refute_includes(described_class.hook_names, :start)
      described_class.send(:enable, 'starts')
      assert_includes(described_class.hook_names, :start)
    end
  end

  def test_build_bang
    skip
  end

  protected

    def assert_pending(*items)
      assert_equal(items.flatten, source_const.class_variable_get(:@@pending).keys)
    end

    def source_const
      Rails::GraphQL::Source
    end
end
