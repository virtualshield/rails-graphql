require 'integration/config'

class Integration_MaxDepthTest < GraphQL::IntegrationTestCase
  NODE = { name: 'n' }
  NODE[:child] = NODE

  class SCHEMA < GraphQL::Schema
    namespace :max_depth

    configure do |config|
      config.max_depth = 3
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    object 'Node' do
      field(:name, :string, null: false)
      field(:child, 'Node', null: false)
    end

    query_fields do
      field(:node, 'Node', null: false).resolve { NODE }
      field(:count, :int, null: false, arguments: argument(:n, :int)).resolve { 1 }
    end

    mutation_fields do
      field(:touch, 'Node', null: false).perform { NODE }
    end
  end

  def setup
    super
    SCHEMA.config.max_depth = 3
    SCHEMA.config.cache.clear
  end

  def test_an_operation_within_the_limit
    assert_result({ data: { node: { child: { name: 'n' } } } }, '{ node { child { name } } }')
    assert_result({ data: { count: 1 } }, '{ count }')
  end

  def test_an_operation_over_the_limit_is_refused
    assert_refused(4, '{ node { child { child { name } } } }')
    assert_refused(4, 'mutation { touch { child { child { name } } } }')
  end

  def test_fragments_count_where_they_are_spread
    assert_refused(4, '{ node { child { ...deep } } } fragment deep on Node { child { name } }')
    assert_refused(4, '{ node { child { ... on Node { child { name } } } } }')
    assert_result({ data: { node: { child: { name: 'n' } } } }, '{ node { ...one } } fragment one on Node { child { name } }')
  end

  def test_typename_counts_as_a_field
    assert_refused(4, '{ node { child { child { __typename } } } }')
    assert_result({ data: { node: { child: { __typename: 'Node' } } } }, '{ node { child { __typename } } }')
  end

  def test_a_global_limit_applies_to_a_schema_without_its_own
    schema = Class.new(GraphQL::Schema) do
      namespace :max_depth_global
      object('Leaf') { field(:name, :string, null: false) }
      query_fields { field(:leaf, 'Leaf', null: false).resolve { { name: 'n' } } }
    end

    GraphQL.config.max_depth = 1
    GraphQL::Schema.config.delete(:max_depth)
    result = execute('{ leaf { name } }', schema: schema)
    assert_equal('Query has depth of 2, which exceeds max depth of 1', result['errors'].first['message'])
  ensure
    GraphQL.config.max_depth = nil
    GraphQL::Schema.config.delete(:max_depth)
  end

  def test_other_operations_in_the_request_still_run
    result = execute('query A { count } query B { node { child { child { name } } } }')
    assert_equal({ 'A' => { 'count' => 1 }, 'B' => nil }, result['data'])
    assert_equal(['Query has depth of 4, which exceeds max depth of 3'], result['errors'].map { |e| e['message'] })
    assert_equal(['B'], result['errors'].first['path'])
  end

  def test_a_cached_document_is_checked_against_the_current_limit
    key = 'stored'
    assert_result({ data: { node: { child: { name: 'n' } } } }, '{ node { child { name } } }', hash: key)
    assert(SCHEMA.cached?(key))
    assert_result({ data: { node: { child: { name: 'n' } } } }, nil, hash: key)

    SCHEMA.config.max_depth = 1
    assert_refused(3, nil, 1, hash: key)
  end

  def test_a_cached_document_with_a_fragment_is_checked_against_the_current_limit
    key = 'stored-fragment'
    document = '{ node { ...deep } } fragment deep on Node { child { name } }'
    assert_result({ data: { node: { child: { name: 'n' } } } }, document, hash: key)
    assert_result({ data: { node: { child: { name: 'n' } } } }, nil, hash: key)

    SCHEMA.config.max_depth = 2
    assert_refused(3, nil, 2, hash: key)
  end

  def test_a_refused_operation_reports_only_the_depth_error
    result = execute('query($n: Int) { count(n: $n) node { child { child { name } } } }', args: { n: 1 })
    assert_equal(['Query has depth of 4, which exceeds max depth of 3'], result['errors'].map { |e| e['message'] })
  end

  def test_skipped_and_denied_selections_count_as_written
    assert_refused(4, '{ node { child @skip(if: true) { child { name } } } }')
    assert_refused(4, '{ node { child { ... on Node @include(if: false) { child { name } } } } }')
    assert_refused(4, '{ node { child { ...deep @skip(if: true) } } } fragment deep on Node { child { name } }')
  end

  def test_the_mutation_performer_does_not_run_when_refused
    calls = 0
    SCHEMA.mutation_field(:touch).perform { calls += 1; NODE }
    assert_refused(4, 'mutation { touch { child { child { name } } } }')
    assert_equal(0, calls)
  ensure
    SCHEMA.mutation_field(:touch).perform { NODE }
  end

  def test_a_fragment_spread_many_times_is_measured_once
    spreads = (1..12).map { |i| "fragment f#{i} on Node { child { ...f#{i + 1} ...f#{i + 1} } }" }.join(' ')
    document = "{ node { ...f1 } } #{spreads} fragment f13 on Node { name }"
    assert_refused(14, document)
  end

  def test_a_limit_given_as_a_string
    SCHEMA.config.max_depth = '3'
    assert_result({ data: { count: 1 } }, '{ count }')
    assert_refused(4, '{ node { child { child { name } } } }')
  end

  private

    def assert_refused(depth, document, limit = 3, **xargs)
      result = execute(document, **xargs)
      assert_equal(['Query has depth of %d, which exceeds max depth of %d' % [depth, limit]], result['errors'].map { |e| e['message'] })
      assert_equal({}, result['data'])
    end
end
