require 'config'

class GraphQL_SourceTest < GraphQL::TestCase
  DESCRIBED_CLASS = Class.new(Rails::GraphQL::Source)

  def after
    source_const.class_variable_set(:@@pending, {})
  end

  alias setup after
  alias teardown after

  def test_kind
    assert_equal(:source, DESCRIBED_CLASS.kind)
  end

  def test_base_type_class
    assert_equal(:Type, DESCRIBED_CLASS.base_type_class)
  end

  def test_base_name
    DESCRIBED_CLASS.stub(:abstract?, true) do
      assert_nil(DESCRIBED_CLASS.base_name)
    end

    DESCRIBED_CLASS.stub(:abstract?, false) do
      assert_equal('DESCRIBED', DESCRIBED_CLASS.base_name)
    end
  end

  def test_inherited
    assert_pending([])

    other = Class.new(DESCRIBED_CLASS)
    refute_predicate(other, :abstract?)
    assert_pending(other)
  end

  def test_find_for_bang
    DESCRIBED_CLASS.stub(:find_for, passthrough) do
      assert_equal(1, DESCRIBED_CLASS.find_for!(1))
    end

    DESCRIBED_CLASS.stub(:find_for, false) do
      assert_raises(StandardError) { DESCRIBED_CLASS.find_for!(double(name: 'A')) }
    end
  end

  def test_find_for
    base  = double(assigned_class: Object)
    one   = double(assigned_class: Class.new)
    other = double(assigned_class: Class.new(one.assigned_class))

    DESCRIBED_CLASS.stub(:base_sources, [base, one, other]) do
      assert_equal(base,  DESCRIBED_CLASS.find_for('Class'))
      assert_equal(one,   DESCRIBED_CLASS.find_for(one.assigned_class))
      assert_equal(one,   DESCRIBED_CLASS.find_for(Class.new(one.assigned_class)))
      assert_equal(other, DESCRIBED_CLASS.find_for(Class.new(other.assigned_class)))
      assert_nil(DESCRIBED_CLASS.find_for('BasicObject'))
    end
  end

  def test_built_ask
    refute_predicate(DESCRIBED_CLASS, :built?)

    DESCRIBED_CLASS.stub_ivar(:@built, false) do
      refute_predicate(DESCRIBED_CLASS, :built?)
    end

    DESCRIBED_CLASS.stub_ivar(:@built, true) do
      assert_predicate(DESCRIBED_CLASS, :built?)
    end
  end

  def test_attach_fields_bang
    schema = Class.new Rails::GraphQL::Schema
    DESCRIBED_CLASS.stub(:schemas, { base: schema } ) do
      DESCRIBED_CLASS.stub(:query_fields, { a: :a_val }) do
        DESCRIBED_CLASS.stub(:mutation_fields, { a: :a_val }) do
          DESCRIBED_CLASS.stub(:subscription_fields, { a: :a_val }) do
            schema.stub(:add_proxy_field, passthrough) do
              assert_predicate(DESCRIBED_CLASS, :attach_fields!)
            end
          end
        end
      end
    end
  end

  def test_refresh_schemas_bang
    DESCRIBED_CLASS.stub(:namespaces, [:base]) do
      schema = Class.new Rails::GraphQL::Schema
      Rails::GraphQL::Schema.stub(:find, schema) do
        assert_equal({ base: schema }, DESCRIBED_CLASS.refresh_schemas!)
      end
    end
  end

  def test_find_type_bang
    DESCRIBED_CLASS.stub(:namespaces, :a) do
      Rails::GraphQL.stub(:type_map, double(fetch!: passallthrough)) do
        settings = { base_class: :Type, namespaces: :a }
        assert_equal([1, settings], DESCRIBED_CLASS.send(:find_type!, 1))

        settings.merge!(other: 2)
        assert_equal([1, settings], DESCRIBED_CLASS.send(:find_type!, 1, other: 2))
      end
    end
  end

  def test_type_map_after_register
    DESCRIBED_CLASS.stub(:namespaces, :a) do
      Rails::GraphQL.stub(:type_map, double(after_register: passallthrough)) do
        settings = { namespaces: :a }
        assert_equal([settings], DESCRIBED_CLASS.send(:type_map_after_register))

        assert_equal([1, settings], DESCRIBED_CLASS.send(:type_map_after_register, 1))

        settings.merge!(o: 2)
        assert_equal([1, settings], DESCRIBED_CLASS.send(:type_map_after_register, 1, o: 2))
      end
    end
  end

  def test_create_enum
    enum = DESCRIBED_CLASS.send(:create_enum, 'test', { 'value' => 0 }, once: true)
    assert_equal "GraphQL::TestEnum", enum.name
    assert_equal Set['VALUE'], enum.values
  end

  def test_skip_on
    hash_list = Hash.new { |h, k| h[k] = Set.new }

    DESCRIBED_CLASS.stub(:segmented_skip_fields, -> { hash_list }) do
      assert_equal(Set[:a], DESCRIBED_CLASS.send(:skip_on, 1, :a))
      assert_equal(Set[:b], DESCRIBED_CLASS.send(:skip_on, 2, 'b'))
      assert_equal(Set[:b, :c, :d], DESCRIBED_CLASS.send(:skip_on, 2, 'c', :d))
    end
  end

  def test_on
    refute_empty DESCRIBED_CLASS.send(:on, :start) { nil }
  end

  def test_skip
    assert_throws :skip do
      DESCRIBED_CLASS.send(:skip, :start)
      DESCRIBED_CLASS.hooks[:start].map(&:call)
    end
  end

  def test_override
    DESCRIBED_CLASS.send(:override, :start) { puts 'test' }
    refute_empty DESCRIBED_CLASS.hooks[:start]
  end

  def test_disable
    DESCRIBED_CLASS.stub(:hook_names, Set[:start]) do
      DESCRIBED_CLASS.send(:on, :start) { puts 'test' }
      DESCRIBED_CLASS.send :disable, :start
      assert_empty DESCRIBED_CLASS.hooks[:start]
    end
  end

  def test_enable
    DESCRIBED_CLASS.stub(:hook_names, Set[:start]) do
      DESCRIBED_CLASS.send(:on, :start) { puts 'test' }
      DESCRIBED_CLASS.send :disable, :start
      assert_empty DESCRIBED_CLASS.hooks[:start]
      DESCRIBED_CLASS.send :enable, :start
      refute_empty DESCRIBED_CLASS.hooks[:start]
    end
  end

  def test_gql_module
    assert_equal(::GraphQL, DESCRIBED_CLASS.send(:gql_module))

    ::GraphQL.stub_const(:Other, Module.new) do
      sample = Class.new(source_const)
      ::GraphQL::Other.const_set(:Source, sample)
      assert_equal(::GraphQL::Other, sample.send(:gql_module))
    end
  end

  def test_skips_for
    DESCRIBED_CLASS.stub(:all_segmented_skip_fields, { input: Set[:created_at] }) do
      DESCRIBED_CLASS.stub(:all_skip_fields, Set[]) do
        assert_equal Set[:created_at], DESCRIBED_CLASS.send(:skips_for, OpenStruct.new(kind: :input_object))
      end
    end
  end

  def test_pending_ask
    refute_predicate(source_const, :pending?)

    sample = Class.new(source_const)
    assert_predicate(source_const, :pending?)
  end

  def test_build_pending_bang
    pending_class = DESCRIBED_CLASS::ActiveRecordSource
    DESCRIBED_CLASS.stub(:pending, { pending_class => 'test'}) do
      assert_nil DESCRIBED_CLASS.send :build_pending!
    end
  end

  def test_build_bang
    DESCRIBED_CLASS.stub_ivar(:@built, true) do
      assert_nil DESCRIBED_CLASS.send :build!
    end

    DESCRIBED_CLASS.stub(:abstract, true) do
      assert_raises(StandardError) { DESCRIBED_CLASS.send :build! }
    end

    DESCRIBED_CLASS.stub(:hook_names, Set[:start]) do
      flag = true
      DESCRIBED_CLASS.send(:on, :start) { flag = false }
      DESCRIBED_CLASS.send :build!
      refute flag
    end
  end

  def test_run_hooks
    assert_respond_to(DESCRIBED_CLASS, :run_start_hooks)
    assert_respond_to(DESCRIBED_CLASS, :run_finish_hooks)
    assert_respond_to(DESCRIBED_CLASS, :run_object_hooks)
    assert_respond_to(DESCRIBED_CLASS, :run_input_hooks)
    assert_respond_to(DESCRIBED_CLASS, :run_query_hooks)
    assert_respond_to(DESCRIBED_CLASS, :run_mutation_hooks)
    assert_respond_to(DESCRIBED_CLASS, :run_subscription_hooks)
  end

  protected

    def assert_pending(*items)
      assert_equal(items.flatten, source_const.class_variable_get(:@@pending).keys)
    end

    def source_const
      Rails::GraphQL::Source
    end
end
