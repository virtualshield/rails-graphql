require 'integration/config'

class Integration_NullLiteralTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :null_literal

    query_fields do
      field(:currency, :string, arguments: argument(:code, :string, default: 'USD'))
        .resolve { |code:| code.inspect }

      field(:required, :string, null: false, arguments: argument(:code, :string, null: false))
        .resolve { |code:| code }

      field(:required_default, :string, null: false, arguments: argument(:code, :string, null: false, default: 'USD'))
        .resolve { |code:| code }
    end
  end

  def test_null_argument_is_null
    assert_result({ data: { currency: 'nil' } }, '{ currency(code: null) }')
    assert_result({ data: { currency: '"USD"' } }, '{ currency }')
    assert_result({ data: { currency: 'nil' } }, 'query($c: String = null) { currency(code: $c) }')
  end

  def test_null_argument_is_refused_where_null_is_not_accepted
    result = execute('{ required(code: null) }')
    assert_equal(['Invalid arguments for required field: the "code" argument can not be null.'], result['errors'].map { |e| e['message'] })

    result = execute('{ currency @include(if: null) }')
    assert_equal(['Invalid arguments for @include directive added to currency field: the "if" argument can not be null.'], result['errors'].map { |e| e['message'] })

    result = execute('{ currency @skip(if: null) }')
    assert_equal(['Invalid arguments for @skip directive added to currency field: the "if" argument can not be null.'], result['errors'].map { |e| e['message'] })

    result = execute('{ requiredDefault(code: null) }')
    assert_equal(['Invalid arguments for requiredDefault field: the "code" argument can not be null.'], result['errors'].map { |e| e['message'] })
    assert_result({ data: { requiredDefault: 'USD' } }, '{ requiredDefault }')

    result = execute('query($c: String! = null) { required(code: $c) }')
    assert_equal(['Invalid arguments for query: the "c" argument can not be null.'], result['errors'].map { |e| e['message'] })
  end
end
