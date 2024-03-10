require 'integration/config'

class Integration_PaginationTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :pagination

    load_directives :paginate

    configure do |config|
      config.enable_string_collector = false
      config.default_response_format = :json
    end

    object 'User' do
      field :names, full: true
    end

    query_fields do
      import Rails::GraphQL::Shared::PaginationField

      field(:hello).resolve { 'Hello World!' }
      field(:users, 'User', full: true).prepare do
        [{ names: ('A'..'Z').to_a }, { names: ('a'..'z').to_a }]
      end
      field(:query1, :int, full: true).prepare { (1..100).to_a }
      field(:query2, :int, full: true) do
        event_types :paginate, append: true
        on :paginate, :reverse_pagination
        prepare { (1..100).to_a }
      end
    end

    def reverse_pagination(entries, page_info, limit:, current:)
      page_info.next = -2
      page_info.previous = -1
      page_info.count = 200 if event.totals?
      entries.reverse.slice(current * limit, limit)
    end
  end

  def test_simple_pages_pagination
    assert_paginated('query1', (1..10), <<~GQL, n: 1)
      query FirstTenByPages { query1 @paginate(limit:10) }
    GQL

    assert_paginated('query1', (11..20), <<~GQL, p: 0, n: 2)
      query TenToTwentyByPages { query1 @paginate(limit:10, current:1) }
    GQL

    assert_paginated('query1', (0...0), <<~GQL)
      query OutOfBoundPages { query1 @paginate(limit:10, current:20) }
    GQL
  end

  def test_simple_offset_pagination
    assert_paginated('query1', (1..10), <<~GQL, n: 10)
      query FirstTenByOffset { query1 @paginate(limit:10, mode:OFFSET) }
    GQL

    assert_paginated('query1', (2..11), <<~GQL, p: 0, n: 11)
      query TwoToElevenByOffset { query1 @paginate(limit:10, mode:OFFSET, current:1) }
    GQL

    assert_paginated('query1', (0...0), <<~GQL)
      query OutOfBoundOffset { query1 @paginate(limit:10, mode:OFFSET, current:110) }
    GQL
  end

  def test_simple_keyset_pagination
    assert_paginated('query1', (1..10), <<~GQL, n: 10.hash.to_s)
      query FirstTenByKeyset { query1 @paginate(limit:10, mode:KEYSET) }
    GQL

    assert_paginated('query1', (6..15), <<~GQL, n: 15.hash.to_s)
      query SixToFifteenByKeyset { query1 @paginate(limit:10, mode:KEYSET, current:"#{5.hash}") }
    GQL

    assert_paginated('query1', (0...0), <<~GQL)
      query OutOfBoundKeyset { query1 @paginate(limit:10, mode:KEYSET, current:"0") }
    GQL
  end

  def test_triggered_pagination
    assert_paginated('query2', (91..100).to_a.reverse, <<~GQL, p: -1, n: -2, t: 200)
      query FirstTenByReverse { query2 @paginate(limit:10) }
    GQL

    assert_paginated('query2', (91..100).to_a.reverse, <<~GQL, p: -1, n: -2, t: nil)
      query FirstTenByReverseNoTotals { query2 @paginate(limit:10, totals:false) }
    GQL
  end

  def test_directive_validation
    assert_match_error(/Field is not an array/, <<~GQL)
      query WrongPlace { hello @paginate(limit:1) }
    GQL

    assert_match_error(/Pagination id cannot be blank/, <<~GQL)
      query EmptyID { query1 @paginate(limit:1, id:"") }
    GQL

    assert_match_error(/has already been taken/, <<~GQL)
      query DuplicatedId {
        query1 @paginate(limit:1, id:"A")
        other: query1 @paginate(limit:2, id:"A")
      }
    GQL

    assert_match_error(/A pagination cannot be defined inside the array/, <<~GQL)
      query Nested { users { names @paginate(limit: 1) } }
    GQL
  end

  def test_query_field_validation
    assert_match_error(/ID "A" was not found/, <<~GQL)
      query MissingID { query1 @paginate(limit:1) pagination(id:"A") { next } }
    GQL
  end

  protected

    def assert_paginated(field, expected, *args, p: nil, n: nil, t: 100, **xargs)
      result = execute(*args, **xargs)
      yield result if block_given?

      t = 26 if expected.is_a?(Range) && String === expected.first
      ext = result.dig('extensions', 'pagination', Array.wrap(field).join('.'))
      page = { previous: p, next: n, count: t }.compact.stringify_keys

      assert_equal(expected.to_a, result.dig('data', *field))
      assert_equal(page, ext.except('pages'))
    end
end
