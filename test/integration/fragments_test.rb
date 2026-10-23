require 'integration/config'

class Integration_FragmentsTest < GraphQL::IntegrationTestCase
  NODE = { name: 'n' }
  NODE[:child] = NODE
  NODE[:loaded] = NODE
  NODE[:total] = 1

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
      field(:total, :int, null: false, arguments: argument(:n, :int))
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

  def test_a_fragment_field_left_out_as_a_duplicate_still_resolves_elsewhere
    assert_result({ data: { node: { name: 'n' }, child: { name: 'n' } } }, <<~GQL)
      { node { name ...b } child: node { ...b } } fragment b on Node { name }
    GQL
  end

  def test_a_fragment_field_left_out_as_invalid_reports_at_every_spread
    result = execute('{ node { ...b } child: node { ...b } } fragment b on Node { total(n: "x") }')
    assert_equal({ 'node' => {}, 'child' => {} }, result['data'])
    assert_equal([%w[node total], %w[node total], %w[child total]], result['errors'].map { |error| error['path'] })
    assert_equal(['The total field value can not be null.'] * 2, messages(result).last(2))
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

  def test_a_chain_measured_by_one_operation_is_checked_in_full_by_another
    [
      "query A { node { ...f3 } } query B { node { ...f1 } } #{chain(66)}",
      "query B { node { ...f1 } } query A { node { ...f3 } } #{chain(66)}",
    ].each do |document|
      result = execute(document)
      assert_equal({ 'A' => { 'node' => { 'name' => 'n' } }, 'B' => nil }, result['data'])
      assert_equal(['Query spreads fragments more than 64 levels deep'], messages(result))
      assert_equal(['B'], result['errors'].first['path'])
    end
  end

  def test_a_fragment_depth_measured_by_one_operation_counts_where_another_spreads_it
    SCHEMA.config.max_depth = 3
    [
      'query A { node { ...a } } query B { node { child { ...a } } } fragment a on Node { child { name } }',
      'query B { node { child { ...a } } } query A { node { ...a } } fragment a on Node { child { name } }',
    ].each do |document|
      result = execute(document)
      assert_equal({ 'A' => { 'node' => { 'child' => { 'name' => 'n' } } }, 'B' => nil }, result['data'])
      assert_equal(['Query has depth of 4, which exceeds max depth of 3'], messages(result))
      assert_equal(['B'], result['errors'].first['path'])
    end
  ensure
    SCHEMA.config.max_depth = nil
  end

  def test_fragment_spreads_followed_up_to_the_limit
    assert_result({ data: { node: { name: 'n' } } }, "{ node { #{'...leaf ' * 10_000} } } fragment leaf on Node { name }")
    assert_refused('Query follows more than 10000 fragment spreads', "{ node { #{'...leaf ' * 10_001} } } fragment leaf on Node { name }")
    assert_result({ data: { node: { name: 'n' } } }, "{ node { ...f1 } } #{fanout(13)}")
    assert_refused('Query follows more than 10000 fragment spreads', "{ node { ...f1 } } #{fanout(14)}")
  end

  def test_each_operation_gets_its_own_count_when_fragments_are_shared
    [
      "query A { node { ...f2 } } query B { node { ...f1 } } #{fanout(14)}",
      "query B { node { ...f1 } } query A { node { ...f2 } } #{fanout(14)}",
    ].each do |document|
      result = execute(document)
      assert_equal({ 'A' => { 'node' => { 'name' => 'n' } }, 'B' => nil }, result['data'])
      assert_equal(['Query follows more than 10000 fragment spreads'], messages(result))
      assert_equal(['B'], result['errors'].first['path'])
    end
  end

  def test_an_operation_refused_for_its_spreads_reports_only_that_error
    result = execute("query($n: Int) { count(n: $n) node { ...f1 } } #{fanout(14)}", args: { n: 1 })
    assert_equal(['Query follows more than 10000 fragment spreads'], messages(result))
  end

  def test_a_cached_document_is_checked_against_the_spreads_limit
    key = 'stored-fanout'
    with_fragment_limit(:MAX_FRAGMENT_SPREADS, 100_000) do
      assert_result({ data: { node: { name: 'n' } } }, "{ node { ...f1 } } #{fanout(14)}", hash: key)
    end

    assert(SCHEMA.cached?(key))
    assert_refused('Query follows more than 10000 fragment spreads', nil, hash: key)
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
    with_fragment_limit(:MAX_FRAGMENT_NESTING, 100) do
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

    # Fragments spreading the next one twice, the last one selecting a field,
    # so the spreads followed double with each level
    def fanout(levels)
      (1...levels).map { |i| "fragment f#{i} on Node { ...f#{i + 1} ...f#{i + 1} }" }.push("fragment f#{levels} on Node { name }").join(' ')
    end

    # Run the block with another value for one of the fragment limits, as a
    # request from a release with a different limit would write the cache
    def with_fragment_limit(name, value)
      operation = GraphQL::Request::Component::Operation
      original = operation.const_get(name)
      operation.send(:remove_const, name)
      operation.const_set(name, value)
      yield
    ensure
      operation.send(:remove_const, name)
      operation.const_set(name, original)
    end
end
