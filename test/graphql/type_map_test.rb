require 'config'

class GraphQL_TypeMapTest < GraphQL::TestCase
  DESCRIBED_CLASS = Rails::GraphQL::TypeMap
  SAMPLE_INDEX = {
    base: { Type: { string: -> { 1 }, boolean: -> { 4 } } },
    other: { Type: { string: -> { 2 }, number: -> { 3 } } },
  }.freeze

  def after
    @subject = nil
  end

  def subject
    @subject ||= DESCRIBED_CLASS.new
  end

  def test_reset_bang
    checkpoint = registered_double
    subject.instance_variable_set(:@objects, 1)
    subject.instance_variable_set(:@version, 2)
    subject.instance_variable_set(:@pending, 3)
    subject.instance_variable_set(:@skip_register, 4)
    subject.instance_variable_set(:@callbacks, 5)
    subject.instance_variable_set(:@dependencies, 6)
    subject.instance_variable_set(:@index, 7)
    subject.reset!

    refute_equal(1, subject.instance_variable_get(:@objects))
    refute_equal(2, subject.instance_variable_get(:@version))
    refute_equal(3, subject.instance_variable_get(:@pending))
    refute_equal(4, subject.instance_variable_get(:@skip_register))
    refute_equal(5, subject.instance_variable_get(:@callbacks))
    refute_equal(6, subject.instance_variable_get(:@dependencies))
    refute_equal(7, subject.instance_variable_get(:@index))
  end

  def test_objects
    assert_empty(subject.objects)
    subject.stub_ivar(:@index, { a: { b: { c: -> { 1 } } } }) do
      assert_empty(subject.objects)
    end

    item = double(
      gql_name: 'name',
      is_a?: ->(klass) { klass == Rails::GraphQL::Helpers::Registerable },
    )

    other = double(gql_name: 'otherName')

    checker = -> { item }
    subject.stub_ivar(:@index, { a: { b: { c: checker }, d: { e: checker }, f: { g: other } } }) do
      assert_empty(subject.objects(namespaces: :z))
      assert_empty(subject.objects(namespaces: :a, base_classes: :z))
      assert_empty(subject.objects(namespaces: :a, base_classes: :f))

      subject.class.stub(:base_classes, %i[b d f]) do
        result = subject.objects
        assert_equal([item], result)
      end
    end
  end

  def test_fetch_bang
    subject.stub(:fetch, passallthrough) do
      assert_equal([1, { a: 2, base_class: :Type }], subject.fetch!(1, a: 2))
      assert_equal([1, { a: 2, base_class: 3 }], subject.fetch!(1, base_class: 3, a: 2))
    end

    loaded = false
    subject.stub(:fetch, ->(*x) { x if loaded }) do
      assert_raises(StandardError) { subject.fetch!(1) }

      subject.stub(:load_dependencies!, ->(*) { loaded = true }) do
        assert_equal([1, {  base_class: :Type }], subject.fetch!(1))
      end
    end
  end

  def test_fetch
    stub_dig do
      assert_registered(9) do
        assert_nil(subject.fetch(:number))
        assert_nil(subject.fetch(:number, base_class: :Other))

        assert_equal(1, subject.fetch(:string))
        assert_equal(1, subject.fetch(:string, prevent_register: true))
        assert_equal(1, subject.fetch(:number, fallback: :string))

        assert_equal(2, subject.fetch(:string, namespaces: :other))
        assert_equal(3, subject.fetch(:number, namespaces: Set[:other]))

        assert_equal(4, subject.fetch(:boolean))
        assert_equal(4, subject.fetch(:boolean, namespaces: :other))
        assert_nil(subject.fetch(:boolean, namespaces: :other, exclusive: true))
      end
    end
  end

  def test_exist_ask
    stub_dig do
      assert(subject.exist?(:string))
      assert(subject.exist?(:string, namespaces: :other))

      assert(subject.exist?(:boolean, namespaces: Set[:other]))
      refute(subject.exist?(:boolean, namespaces: :other, exclusive: true))

      refute(subject.exist?(:number))
      refute(subject.exist?(:number, base_class: :Other))
    end
  end

  def test_object_exist_ask
    subject.stub(:exist?, passallthrough) do
      subject.stub(:find_base_class, passthrough) do
        object = double(namespaces: :a)
        xargs = { base_class: object, namespaces: :a, other: 1 }
        assert_equal([object, xargs], subject.object_exist?(object, other: 1))
      end
    end
  end

  def test_postpone_registration
    result = subject.get_reset_ivar(:@pending, []) { postpone_registration(1) }
    assert_instance_of(String, result[0][1])
    assert_equal(1, result[0][0])
  end

  def test_register
    subject.stub(:find_base_class, passthrough) do
      subject.stub(:ensure_base_class!, ->(*) { raise }) do
        assert_raises(StandardError) { subject.register(1) }
      end

      subject.stub(:ensure_base_class!, passthrough) do
        added = []
        fake_add = ->(*args) { added << args }

        subject.stub(:add, fake_add) do
          object1 = double(gql_name: 'string', to_sym: :string, namespaces: nil)
          result = subject.register(object1)

          assert_equal(2, added.size)
          assert_equal(object1, result)
          assert_equal([:base, object1, :string],  added[0][0..-2])
          assert_equal([:base, object1, 'string'], added[1][0..-2])

          subject.stub(:fetch, passallthrough) do
            xargs = { base_class: object1, namespaces: :base, exclusive: true }
            assert_equal([:string, xargs], added[1][-1].call)
            assert_equal(object1, added[0][-1])
          end

          assert_equal(1, subject.instance_variable_get(:@objects))

          added.clear
          subject.register(object2 = double(
            gql_name: 'number',
            to_sym: :number,
            namespaces: [:a, :b, :c],
            aliases: [:num, :n],
          ))

          object2.namespaces.each do |ns|
            assert_equal([ns, object2, :number],  added.shift[0..-2])
            assert_equal([ns, object2, 'number'], added.shift[0..-2])
            assert_equal([ns, object2, :num],     added.shift[0..-2])
            assert_equal([ns, object2, :n],       added.shift[0..-2])
          end

          assert_equal(2, subject.instance_variable_get(:@objects))
        end
      end
    end
  end

  def test_register_alias
    assert_raises(StandardError) { subject.register_alias(:a) }
    subject.stub(:ensure_base_class!, ->(*) { raise }) do
      assert_raises(StandardError) { subject.register_alias(:a, key: :a) }
      assert_raises(StandardError) { subject.register_alias(:a) { :b } }
    end

    subject.stub(:ensure_base_class!, passthrough) do
      added = []
      fake_add = ->(*args) { added << args }

      subject.stub(:add, fake_add) do
        subject.register_alias(:a, :string)
        assert_equal([:base, :Type, :a], added[0][0..-2])

        subject.stub(:fetch, passallthrough) do
          xargs = { base_class: :Type, namespaces: [:base], exclusive: true }
          assert_equal([:string, xargs], added[0][-1].call)
        end

        subject.register_alias(:b) { :c }
        assert_equal([:base, :Type, :b], added[1][0..-2])
        assert_equal(:c, added[1][-1].call)

        subject.register_alias(:d, base_class: :Other, namespace: :sample) { :e }
        assert_equal([:sample, :Other, :d], added[2][0..-2])
        assert_equal(:e, added[2][-1].call)
      end
    end
  end

  def test_each_from
    assert_registered(4) do
      Integer.stub_imethod(:gql_name, -> { to_s }) do
        subject.stub_ivar(:@index, SAMPLE_INDEX) do
          items = [1, 4]
          subject.each_from(:base) { |x| assert_equal(items.shift, x) }

          assert_equal([2, 3, 1, 4], subject.each_from(:other).entries)
          assert_equal([2, 3], subject.each_from(:other, exclusive: true).entries)
          assert_equal([], subject.each_from(:other, base_class: :Other).entries)
        end
      end
    end
  end

  def test_after_register
    subject.stub(:fetch, passallthrough) do
      result = subject.after_register(:a, &passthrough)
      xargs = { prevent_register: true, base_class: :Type }
      assert_equal([:a, xargs], result)
    end

    register = Hash.new { |h, k| h[k] = [] }
    checker = ->(x) { assert_equal(:called, x) }

    subject.stub(:fetch, ->(*) {}) do
      subject.stub(:callbacks, register) do
        subject.after_register(:a, &checker)
        subject.after_register(:a, base_class: :Other, &checker)
        subject.after_register(:a, namespaces: :other, &checker)
        subject.after_register(:a, namespaces: Set[:other], &checker)
      end
    end

    assert_equal(1, register.size)
    assert_equal(4, register[:a].size)

    [
      [:base, :Type],
      [:base, :Other],
      [:other, :Type],
      [:other, :Type],
    ].each_with_index do |(ns, bc), idx|
      assert_nil(register[:a][3 - idx].call(:x, bc, :non_called))
      assert_nil(register[:a][3 - idx].call(ns, :y, :non_called))
      assert(register[:a][3 - idx].call(ns, bc, :called))
    end
  end

  def test_inspect
    assert_equal(<<~INFO.squish, subject.inspect)
      #<Rails::GraphQL::TypeMap [index]
      @namespaces=0
      @base_classes=3
      @objects=0
      @pending=0
      @dependencies={base: 14}>
    INFO
  end

  def test_add
    item = {}
    last = []

    subject.stub_ivar(:@index, ->(*args) { last = args; item }.curry(2)) do
      subject.send(:add, 1, 2, 3, 4)
      assert_equal({ 3 => 4 }, item)
      assert_equal([1, 2], last)

      callbacks = { 7 => [
        ->(*args) { assert_equal([5, 6, :a], args); 0 },
        ->(*args) { assert_equal([5, 6, :a], args); nil },
        ->(*args) { assert_equal([5, 6, :a], args); 2 },
      ]}

      subject.stub(:callbacks, callbacks) do
        subject.send(:add, 5, 6, 7, -> { :a })
        assert_equal(:a, item.values.last.call)
        assert_equal(7, item.keys.last)
        assert_equal([5, 6], last)

        assert_equal(1, callbacks.size)
        assert_equal(1, callbacks[7].size)
        assert_nil(callbacks[7][0].call(5, 6, :a))
      end

      callbacks = { 0 => [->(*args) { assert_equal([8, 9, :b], args); 0 }]}
      subject.stub(:callbacks, callbacks) do
        subject.send(:add, 8, 9, 0, -> { :b })
        assert_equal(:b, item.values.last.call)
        assert_equal(0, item.keys.last)
        assert_equal([8, 9], last)

        assert_equal(0, callbacks.size)
      end
    end
  end

  def test_register_pending_bang
    registered = false
    object = double(register!: -> { registered = true }, registered?: false)
    skipped = double(registered?: false)
    other = double(registered?: true)

    subject.stub(:skip_register, [skipped]) do
      subject.stub_ivar(:@pending, [[skipped, :a], [object, :b], [other, :c]]) do
        subject.send(:register_pending!)
        assert(registered)

        items = subject.instance_variable_get(:@pending)
        assert_equal(1, items.size)
        assert_equal([skipped, :a], items[0])
      end
    end
  end

  def test_find_base_class
    assert_equal(:a, subject.send(:find_base_class, double(base_type_class: :a)))
    assert_equal(:String, subject.send(:find_base_class, String))

    klass = Rails::GraphQL::Type::Scalar::StringScalar
    assert_equal(:Type, subject.send(:find_base_class, klass))
  end

  protected

    def assert_registered(times = 1, &block)
      counter = 0
      subject.stub(:register_pending!, -> { counter += 1 }, &block)
      assert_equal(times, counter)
    end

    def stub_dig(index = SAMPLE_INDEX, &block)
      subject.stub(:dig, index.method(:dig), &block)
    end

    def registered_double
      double(register!: -> { define_singleton_method(:registered?) { true } })
    end
end
