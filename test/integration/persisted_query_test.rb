require 'integration/config'

class Integration_PersistedQueryTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :cached

    configure do |config|
      config.enable_string_collector = false
      config.default_response_format = :json
    end

    query_fields do
      field(:one, :string).resolve { 'One!' }
      field(:two, :string).resolve { 'Two!' }
    end

    class_attribute :cache, instance_writer: false, default: {}

    class << self
      def cached?(name, *)
        cache.key?(name)
      end

      def delete_from_cache(name, *)
        cache.delete(name)
      end

      def read_from_cache(name, *)
        cache[name]
      end

      def write_on_cache(name, value, *)
        cache[name] = value
      end
    end
  end

  def teardown
    SCHEMA.cache.clear
  end

  def test_uncached_query
    assert_result('One!', :one)
  end

  def test_cache_key
    gen_key = cache_key('B')
    assert_equal('graphql/cached/A', SCHEMA.send(:expand_cache_key, 'A'))
    assert_equal('graphql/cached/B', SCHEMA.send(:expand_cache_key, gen_key).cache_key)
  end

  def test_cached_query
    value = ::GQLParser.parse_execution('{ two }')
    SCHEMA.write_on_cache((key = cache_key), value)
    assert_result('Two!', :two, hash: key, cache_only: true)
  end

  def test_persist_query
    assert_result('One!', :one, hash: (key = cache_key))
    assert_operator(SCHEMA, :cached?, key)
  end

  def test_subsequent_query
    assert_result('One!', :one, hash: (key = cache_key))
    assert_result('One!', :one, hash: key, cache_only: true)
  end

  def test_execute_compiled_query
    query = GraphQL.compile('{ one }', schema: SCHEMA)
    result = GraphQL.execute(query, compiled: true, schema: SCHEMA)

    assert_equal('One!', result.dig('data', 'one'))
  end

  private

    def cache_key(key = nil, version = nil)
      key ||= SCHEMA.config.cache_prefix + SecureRandom.uuid
      Rails::GraphQL::CacheKey.new(key, version)
    end

    def assert_result(value, field, **options)
      query = options.delete(:cache_only) ? nil : "{ #{field} }"
      result = GraphQL.execute(query, **options, schema: SCHEMA)
      assert_equal(value, result.dig('data', field.to_s))
    end
end
