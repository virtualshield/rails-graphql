require 'integration/config'

class Integration_SchemaListenersTest < GraphQL::IntegrationTestCase
  STATIC = { 'data' => nil }.freeze

  class TrackDirective < GraphQL::Directive
    namespace :schema_listeners
    placed_on :schema
    rename! 'track'

    %i[request mutation organized prepared finalize].each do |event_name|
      on(event_name, exclusive_callback: false) do |event|
        event.context.calls << [event_name, event.source.kind]
      end
    end

    on(:mutation) { |event| event.context.calls << :exclusive }

    on(:mutation, exclusive_callback: false) do |event|
      raise 'Broken' if event.context.broken
      event.context.calls << [:operations, event.request.operations.keys.map(&:to_s)] if event.context.record_operations
      event.request.force_response(STATIC) if event.context.static
      next unless event.context.read_only

      event.request.report_node_error('Read only', event.source)
      event.source.invalidate!(:authorization)
    end
  end

  class SCHEMA < GraphQL::Schema
    namespace :schema_listeners

    use TrackDirective.new

    configure do |config|
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    rescue_from(RuntimeError) { |error| raise error if error.request.context.reraise }

    rescue_from(Rails::GraphQL::PersistedQueryNotFound) do |error|
      error.request.force_response(STATIC, error) unless error.request.context.swallow
    end

    object 'Thing' do
      field(:name, :string)
      field(:bad, :string).on(:organized) { |event| raise 'Bad' if event.context.broken }
      field(:secret, :string).authorize do |event|
        raise 'Broken' if event.context.broken
        event.context.read_only ? event.unauthorized! : event.authorized!
      end
    end

    query_fields do
      field(:one, :string).resolve { 'One!' }

      field(:thing, 'Thing')
        .authorize { |event| event.context.denied ? event.unauthorized! : event.authorized! }
        .on(:organized, exclusive_callback: false) { |event| context.calls << [:parent, event.source.gql_name] }
        .resolve { { name: 'Thing!' } }
    end

    mutation_fields do
      field(:two, :string, arguments: argument(:v, :string, default: 'Two!'))
        .perform { context.calls << :performed }
        .resolve { |v:| v }

      field(:three, 'Thing').perform { context.calls << :performed }.resolve { {} }
    end
  end

  MUTATION_STARTED = [:mutation, :operation].freeze

  MUTATION_CALLS = [
    [:request, :schema],
    MUTATION_STARTED,
    [:organized, :field],
    [:organized, :operation],
    :performed,
    [:prepared, :field],
    [:prepared, :operation],
    [:finalize, :field],
    [:finalize, :operation],
  ].freeze

  QUERY_CALLS = [
    [:request, :schema],
    [:organized, :field],
    [:organized, :operation],
    [:finalize, :field],
    [:finalize, :operation],
  ].freeze

  def teardown
    SCHEMA.config.cache.clear
    super
  end

  def test_mutation
    calls, result = execute_tracked('mutation { two }')

    assert_equal(MUTATION_CALLS, calls)
    assert_equal('Two!', result.dig('data', 'two'))
  end

  def test_query
    calls, result = execute_tracked('{ one }')

    assert_equal(QUERY_CALLS, calls)
    assert_equal('One!', result.dig('data', 'one'))
  end

  def test_refusing_an_operation
    document = 'query A { one } mutation B { two } mutation C { two }'
    calls, result = execute_tracked(document, read_only: true)

    assert_equal(2, calls.count(MUTATION_STARTED))
    refute_includes(calls, :performed)
    assert_equal({ 'A' => { 'one' => 'One!' }, 'B' => nil, 'C' => nil }, result['data'])
    assert_equal(['Read only', 'Read only'], result['errors'].pluck('message'))
  end

  def test_listener_exception
    calls, result = execute_tracked('mutation { two }', broken: true)

    refute_includes(calls, :performed)
    assert_equal('Broken', result.dig('errors', 0, 'message'))
    assert_equal('organize', result.dig('errors', 0, 'extensions', 'stage'))
  end

  def test_cached_document
    key = 'stored'
    SCHEMA.write_on_cache(key, ::GQLParser.parse_execution('mutation { two(v: "x") }'))

    calls, result = execute_tracked(nil, hash: key)
    assert_equal(MUTATION_CALLS, calls)
    assert_equal('x', result.dig('data', 'two'))

    assert_kind_of(String, SCHEMA.read_from_cache(key))

    calls, result = execute_tracked(nil, hash: key)
    assert_equal(MUTATION_CALLS, calls)
    assert_equal('x', result.dig('data', 'two'))

    fresh = execute_tracked('mutation { two(v: "x") }', read_only: true)
    assert_equal(1, fresh.first.count(MUTATION_STARTED))
    refute_includes(fresh.first, :performed)
    assert_equal(fresh, execute_tracked(nil, hash: key, read_only: true))

    fresh = execute_tracked('mutation { two(v: "x") }', broken: true)
    refute_includes(fresh.first, :performed)
    assert_equal(fresh, execute_tracked(nil, hash: key, broken: true))
  end

  def test_refused_document_is_not_stored_in_cache
    key = 'refused'
    request = Rails::GraphQL::Request.new(SCHEMA)

    calls, = execute_tracked('mutation { two(v: "x") }', hash: key, read_only: true, request: request)
    refute_includes(calls, :performed)
    refute(SCHEMA.cached?(key))

    calls, result = execute_tracked('mutation { two(v: "x") }', hash: key, request: request)
    assert_equal(MUTATION_CALLS, calls)
    assert_equal('x', result.dig('data', 'two'))
    assert(SCHEMA.cached?(key))
  end

  def test_request_operations_during_cached_events
    key = 'operations'
    document = 'mutation A { two } mutation B { two }'

    operations = ->(calls) { calls.grep(Array).select { |call| call.first == :operations }.map(&:last) }

    fresh = execute_tracked(document, record_operations: true)
    assert_equal([%w[A B], %w[A B]], operations.call(fresh.first))

    execute_tracked(document, hash: key)
    assert_equal([%w[A B], %w[A B]], operations.call(execute_tracked(nil, hash: key, record_operations: true).first))
  end

  def test_refused_document_cannot_be_compiled
    request = Rails::GraphQL::Request.new(SCHEMA)
    request.context = { calls: [], read_only: true }

    error = assert_raises(Rails::GraphQL::ExecutionError) { request.compile('mutation { two }') }
    assert_match(/Read only/, error.message)

    request.context = { calls: [], broken: true }
    error = assert_raises(Rails::GraphQL::ExecutionError) { request.compile('mutation { two }') }
    assert_match(/Broken/, error.message)
  end

  def test_escaped_exception_is_not_stored_in_cache
    key = 'escaped'

    assert_raises(RuntimeError) do
      execute_tracked('mutation { two }', hash: key, broken: true, reraise: true)
    end

    refute(SCHEMA.cached?(key))
  end

  def test_static_response_is_not_stored_in_cache
    key = 'static'

    calls, result = execute_tracked('mutation { two }', hash: key, static: true)
    refute_includes(calls, :performed)
    assert_equal(STATIC, result)
    refute(SCHEMA.cached?(key))
  end

  def test_missing_persisted_query
    key = Rails::GraphQL::CacheKey.new('missing')

    assert_equal(STATIC, execute_tracked(nil, hash: key).last)
    assert_raises(ArgumentError) { execute_tracked(nil, hash: 'missing') }

    result = execute_tracked(nil, hash: key, swallow: true).last
    assert_equal(['PersistedQueryNotFound'], result['errors'].pluck('message'))
    refute(result.key?('data'))
  end

  def test_persisted_query_key
    document = 'mutation { two(v: "x") }'
    digest = Digest::SHA256.hexdigest(document)
    key = Rails::GraphQL::CacheKey.new(digest)

    assert_equal('x', execute_tracked(document, hash: key).last.dig('data', 'two'))
    assert_equal(digest, key.cache_key)

    calls, result = execute_tracked(nil, hash: Rails::GraphQL::CacheKey.new(digest))
    assert_equal(MUTATION_CALLS, calls)
    assert_equal('x', result.dig('data', 'two'))
  end

  def test_persisted_query_stored_as_a_document
    key = Rails::GraphQL::CacheKey.new(Digest::SHA256.hexdigest('mutation { two }'))
    SCHEMA.write_on_cache(key, ::GQLParser.parse_execution('mutation { two }'))

    calls, result = execute_tracked(nil, hash: key)
    assert_equal(MUTATION_CALLS, calls)
    assert_equal('Two!', result.dig('data', 'two'))
    assert_kind_of(String, SCHEMA.read_from_cache(key))
  end

  def test_persisted_query_key_that_is_not_the_digest
    key = Rails::GraphQL::CacheKey.new(Digest::SHA256.hexdigest('{ one }'))

    assert_equal('x', execute_tracked('mutation { two(v: "x") }', hash: key).last.dig('data', 'two'))
    assert_equal(STATIC, execute_tracked(nil, hash: key).last)
  end

  def test_refused_document_with_nested_fields
    key = 'nested'
    document = 'mutation { three { secret } }'

    fresh = execute_tracked(document, read_only: true)
    assert_equal(['Read only'], fresh.last['errors'].pluck('message'))

    execute_tracked(document, hash: key)
    assert_equal(fresh, execute_tracked(nil, hash: key, read_only: true))
  end

  def test_nested_fields_stored_in_cache
    key = 'thing'
    document = '{ thing { name bad secret } }'

    fresh = execute_tracked(document)
    assert_equal([[:parent, 'name'], [:parent, 'bad'], [:parent, 'secret'], [:parent, 'thing']], fresh.first.grep(Array).select { |call| call.first == :parent })

    execute_tracked(document, hash: key)
    assert_equal(fresh, execute_tracked(nil, hash: key))

    fresh = execute_tracked(document, broken: true)
    assert_equal([%w[thing bad], %w[thing secret]], fresh.last['errors'].pluck('path'))
    assert_equal(fresh, execute_tracked(nil, hash: key, broken: true))

    fresh = execute_tracked(document, read_only: true)
    assert_equal(%w[thing secret], fresh.last.dig('errors', 0, 'path'))
    assert_equal(fresh, execute_tracked(nil, hash: key, read_only: true))

    fresh = execute_tracked(document, read_only: true, denied: true)
    assert_equal([%w[thing]], fresh.last['errors'].pluck('path'))
    assert_equal(fresh, execute_tracked(nil, hash: key, read_only: true, denied: true))
  end

  def test_broken_document_is_not_stored_in_cache
    key = 'broken'

    calls, result = execute_tracked('mutation { two }', hash: key, broken: true)
    refute_includes(calls, :performed)
    assert_equal('Broken', result.dig('errors', 0, 'message'))
    refute(SCHEMA.cached?(key))
  end

  def test_invalid_document_is_not_stored_in_cache
    key = 'invalid'

    result = execute_tracked('mutation { nope }', hash: key).last
    assert_match(/nope/, result.dig('errors', 0, 'message'))
    refute(SCHEMA.cached?(key))

    result = execute_tracked('mutation {', hash: key).last
    assert_match(/Parser error/, result.dig('errors', 0, 'message'))
    refute(SCHEMA.cached?(key))

    result = execute_tracked('query A { one } query A { one: one }', hash: key).last
    assert_match(/Duplicated operation/, result.dig('errors', 0, 'message'))
    refute(SCHEMA.cached?(key))

    document = '{ ...F } fragment F on _Query { one } fragment F on _Query { one: one }'
    result = execute_tracked(document, hash: key).last
    assert_equal(['Duplicated fragment named "F" defined on line 1:10'], result['errors'].pluck('message'))
    refute(SCHEMA.cached?(key))
  end

  def test_invalid_document_stored_by_an_older_version
    key = 'older'
    document = '{ nope one }'

    Rails::GraphQL::Request.stub_imethod(:uncacheable!, ->(*) {}) do
      execute_tracked(document, hash: key)
    end

    assert(SCHEMA.cached?(key))
    assert_equal(execute_tracked(document), execute_tracked(nil, hash: key))
  end

  private

    def execute_tracked(*args, request: nil, **xargs)
      calls = []
      context = { calls: calls }
      context.merge!(xargs.extract!(:read_only, :broken, :reraise, :static, :swallow, :denied, :record_operations))

      result =
        if request.nil?
          execute(*args, **xargs, context: context)
        else
          request.context = context
          request.execute(*args, **xargs, as: :object)
        end

      [calls, result]
    end
end
