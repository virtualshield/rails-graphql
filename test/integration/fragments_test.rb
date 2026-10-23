require 'integration/config'

class Integration_FragmentsTest < GraphQL::IntegrationTestCase
  NODE = { name: 'n' }
  NODE[:child] = NODE
  NODE[:loaded] = NODE

  class Provider
    attr_reader :items

    def initialize
      @items = {}
    end

    def add(*subscriptions)
      subscriptions.each { |item| @items[item.sid] = item }
    end

    def accepts?(*)
      true
    end

    def remove(*sids)
      sids.each { |sid| @items.delete(sid) }
    end

    def fetch(sid)
      @items[sid]
    end

    def shutdown
    end
  end

  PROVIDER = Provider.new
  PREPARES = []

  class SCHEMA < GraphQL::Schema
    namespace :fragments

    configure do |config|
      config.cache = ActiveSupport::Cache::MemoryStore.new
      config.subscription_provider = PROVIDER
    end

    object 'Node' do
      field(:name, :string, null: false)
      field(:child, 'Node', null: false)
      field(:loaded, 'Node', null: false).prepare { PREPARES << true; NODE }
    end

    query_fields do
      field(:node, 'Node', null: false).resolve { NODE }
      field(:prepared, 'Node', null: false).prepare { NODE }
      field(:count, :int, null: false, arguments: argument(:n, :int)).resolve { 1 }
    end

    subscription_fields do
      field(:watch, 'Node', null: false).resolve { NODE }
    end
  end

  def setup
    super
    SCHEMA.config.cache.clear
    PROVIDER.items.clear
    PREPARES.clear
  end

  def test_a_spread_of_an_undefined_fragment
    result = execute('{ node { name ...missing } }')
    assert_equal({ 'node' => { 'name' => 'n' } }, result['data'])
    assert_equal(['The "missing" fragment is not defined in this request.'], messages(result))

    result = execute('{ node { name ...other ...missing } } fragment other on Node { name }')
    assert_equal({ 'node' => { 'name' => 'n' } }, result['data'])
    assert_equal(['The "missing" fragment is not defined in this request.'], messages(result))
  end

  def test_a_spread_of_an_undefined_fragment_under_a_field_with_a_prepare_step
    result = execute('{ prepared { name ...missing } }')
    assert_equal({ 'prepared' => { 'name' => 'n' } }, result['data'])
    assert_equal(['The "missing" fragment is not defined in this request.'], messages(result))
  end

  def test_a_skipped_spread_does_not_prepare_its_fragment
    result = execute('{ prepared { ...a @skip(if: true) } child: prepared { ...a } } fragment a on Node { loaded { name } }')
    assert_nil(result['errors'])
    assert_equal({ 'loaded' => { 'name' => 'n' } }, result['data']['child'])
    assert_equal(1, PREPARES.size)
  end

  def test_a_fragment_that_spreads_itself_is_refused
    assert_refused('Cannot spread fragment "a" within itself', <<~GQL)
      { node { ...a } } fragment a on Node { child { ...a } }
    GQL

    assert_refused('Cannot spread fragment "a" within itself', <<~GQL)
      { node { ...a } } fragment a on Node { name ...a }
    GQL
  end

  def test_a_fragment_that_spreads_itself_through_other_fragments_is_refused
    assert_refused('Cannot spread fragment "a" within itself via "b"', <<~GQL)
      { node { ...a } } fragment a on Node { ...b } fragment b on Node { child { ...a } }
    GQL

    assert_refused('Cannot spread fragment "b" within itself via "c"', <<~GQL)
      { node { ...a } }
      fragment a on Node { ...b }
      fragment b on Node { ...c }
      fragment c on Node { ...b }
    GQL
  end

  def test_a_fragment_that_spreads_itself_through_an_inline_fragment_is_refused
    assert_refused('Cannot spread fragment "a" within itself', <<~GQL)
      { node { ...a } } fragment a on Node { ... on Node { ...a } }
    GQL
  end

  def test_a_fragment_spread_on_two_paths_is_not_a_cycle
    assert_result({ data: { node: { name: 'n' } } }, <<~GQL)
      { node { ...a ...b } }
      fragment a on Node { ...c }
      fragment b on Node { ...c }
      fragment c on Node { name }
    GQL
  end

  def test_fragments_spread_up_to_the_limit
    assert_result({ data: { node: { name: 'n' } } }, "{ node { ...f1 } } #{chain(64)}")
    assert_refused('Query spreads fragments more than 64 levels deep', "{ node { ...f1 } } #{chain(65)}")
    assert_refused('Query spreads fragments more than 64 levels deep', "{ node { ...f1 } } #{chain(20_000)}")
  end

  def test_a_chain_reached_through_a_shorter_path_is_measured_in_full
    assert_refused('Query spreads fragments more than 64 levels deep', "{ node { ...f3 ...f1 } } #{chain(66)}")
  end

  def test_other_operations_in_the_request_still_run
    result = execute(<<~GQL)
      query A { node { name } }
      query B { node { ...a } }
      fragment a on Node { child { ...a } }
    GQL

    assert_equal({ 'A' => { 'node' => { 'name' => 'n' } }, 'B' => nil }, result['data'])
    assert_equal(['Cannot spread fragment "a" within itself'], messages(result))
    assert_equal(['B'], result['errors'].first['path'])
  end

  def test_a_refused_operation_reports_only_its_error
    result = execute('query($n: Int) { count(n: $n) node { ...a } } fragment a on Node { child { ...a } }', args: { n: 1 })
    assert_equal(['Cannot spread fragment "a" within itself'], messages(result))
  end

  def test_a_cached_document_is_checked_against_the_limit
    key = 'stored-chain'
    with_fragment_nesting(100) do
      assert_result({ data: { node: { name: 'n' } } }, "{ node { ...f1 } } #{chain(65)}", hash: key)
    end

    assert(SCHEMA.cached?(key))
    assert_refused('Query spreads fragments more than 64 levels deep', nil, hash: key)
  end

  def test_a_subscription_update_reuses_a_fragment_a_query_built_first
    result = execute('query Q { node { ...a } } subscription S { watch { ...a } } fragment a on Node { name }')
    assert_nil(result['errors'])
    assert_equal(1, PROVIDER.items.size)

    result = execute(nil, hash: PROVIDER.items.keys.first)
    assert_nil(result['errors'])
    assert_equal({ 'watch' => { 'name' => 'n' } }, result['data'])
  end

  private

    # A chain of +size+ fragments, each spreading the next, the last one
    # selecting a field
    def chain(size)
      (1...size).map { |i| "fragment f#{i} on Node { ...f#{i + 1} }" }.push("fragment f#{size} on Node { name }").join(' ')
    end

    def messages(result)
      Array(result['errors']).map { |error| error['message'] }
    end

    def assert_refused(message, document, **xargs)
      result = execute(document, **xargs)
      assert_equal([message], messages(result))
      assert_equal({}, result['data'])
    end

    # Run the block with another nesting limit, as a request from a release
    # with a different limit would write the cache
    def with_fragment_nesting(limit)
      operation = GraphQL::Request::Component::Operation
      original = operation::MAX_FRAGMENT_NESTING
      operation.send(:remove_const, :MAX_FRAGMENT_NESTING)
      operation.const_set(:MAX_FRAGMENT_NESTING, limit)
      yield
    ensure
      operation.send(:remove_const, :MAX_FRAGMENT_NESTING)
      operation.const_set(:MAX_FRAGMENT_NESTING, original)
    end
end
