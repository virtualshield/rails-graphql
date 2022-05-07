require 'integration/config'

class Integration_AuthorizationTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :authorization

    configure do |config|
      config.enable_string_collector = false
    end

    query_fields do
      field(:sample1, :string).resolve { 'Ok 1' }
      field(:sample2, :string).authorize.resolve { 'Ok 2' }
    end
  end

  EXCEPTION_NAME = 'Rails::GraphQL::UnauthorizedFieldError'
  EXCEPTION_PATH = ['errors', 0, 'extensions', 'exception']

  SAMPLE1 = { data: { sample1: 'Ok 1' } }
  SAMPLE2 = { data: { sample2: 'Ok 2' } }

  def test_field_event_types
    assert_includes(SCHEMA.query_field(:sample1).event_types, :authorize)
  end

  def test_without_authorization
    assert_result(SAMPLE1, '{ sample1 }')
  end

  def test_with_simple_authorization
    assert_exception('{ sample2 }')
    assert_result({ sample1: 'Ok 1', sample2: nil }, '{ sample1 sample2 }', dig: 'data')

    SCHEMA.stub_imethod(:authorize!, -> { authorized! }) do
      assert_result(SAMPLE2, '{ sample2 }')
    end

    SCHEMA.stub_imethod(:authorize!, -> { unauthorized! }) do
      assert_exception('{ sample2 }')
    end
  end

  def test_with_block_authorization
    field = SCHEMA.query_field(:sample1)

    field.stub_ivar(:@authorizer, [[], {}, method(:executed!)]) do
      assert_executed { assert_result(SAMPLE1, '{ sample1 }') }
    end

    block = ->(ev) { executed! && ev.unauthorized! }
    field.stub_ivar(:@authorizer, [[], {}, block]) do
      assert_executed { assert_exception('{ sample1 }') }
    end
  end

  def test_with_field_event_authorization
    field = SCHEMA.query_field(:sample2)

    field.stub_ivar(:@events, { authorize: [method(:executed!)] }) do
      assert_executed { assert_result(SAMPLE2, '{ sample2 }') }

      assert_executed do
        field.on(:authorize) { |event| event.unauthorized! }
        assert_exception('{ sample2 }')
      end
    end
  end

  def test_with_directive
    field = SCHEMA.query_field(:sample2)

    auth_directive = unmapped_class(Rails::GraphQL::Directive)
    auth_directive.on(:authorize, &method(:executed!))

    auth_directive.stub_ivar(:@gql_name, 'AuthDirective') do
      field.stub_ivar(:@directives, [auth_directive.new]) do
        assert_executed { assert_result(SAMPLE2, '{ sample2 }') }
      end

      SCHEMA.stub_ivar(:@directives, [auth_directive.new]) do
        assert_executed { assert_result(SAMPLE2, '{ sample2 }') }
      end
    end
  end

  def test_authorize_bypass
    field = SCHEMA.query_field(:sample2)
    counter = method(:executed!)
    auth_block   = ->(ev = nil) { counter.call && (ev || itself).authorized!   }
    unauth_block = ->(ev = nil) { counter.call && (ev || itself).unauthorized! }

    field.stub_ivar(:@events, { authorize: [unauth_block] }) do
      SCHEMA.stub_imethod(:authorize!, auth_block) do
        assert_executed { assert_result(SAMPLE2, '{ sample2 }') }
      end
    end

    field.stub_ivar(:@events, { authorize: [auth_block] }) do
      SCHEMA.stub_imethod(:authorize!, unauth_block) do
        assert_executed { assert_exception('{ sample2 }') }
      end
    end
  end

  protected

    def executed!(*)
      @executed += 1
    end

    def assert_executed(times = 1)
      @executed = 0
      yield
      assert_equal(times, @executed)
    ensure
      remove_instance_variable(:@executed)
    end

    def assert_exception(query, *args, **xargs)
      assert_result(EXCEPTION_NAME, query, *args, dig: EXCEPTION_PATH, **xargs)
    end
end
