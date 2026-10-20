require 'integration/config'

class Integration_ListLiteralTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :list_literal

    query_fields do
      field(:sum, :int, null: false, arguments: argument(:values, :int, array: true, null: false))
        .resolve { |values:| values.sum }

      field(:names, :string, null: false, arguments: argument(:values, :string, array: true, null: false))
        .resolve { |values:| values.join(',') }

      field(:items, :string, null: false, arguments: argument(:values, :int, array: true, nullable: true))
        .resolve { |values:| values.inspect }
    end
  end

  def test_null_inside_an_inline_list
    assert_result({ data: { items: '[1, nil]' } }, '{ items(values: [1, null]) }')
    assert_result({ data: { items: '[nil]' } }, 'query($v: [Int] = [null]) { items(values: $v) }')
  end

  def test_invalid_inline_list_is_reported_as_written
    result = execute('{ sum(values: [1, "x"]) }')
    assert_includes(result['errors'].first['message'], 'Invalid value "["1", "\\"x\\""]" provided to values argument on sum')

    result = execute('query($v: Int = [1]) { sum(values: [1]) }')
    assert_match(/The given default value .* is not valid for this argument/, result['errors'].first['message'])
  end

  def test_inline_list_argument
    assert_result({ data: { sum: 3 } }, '{ sum(values: [1, 2]) }')
    assert_result({ data: { sum: 0 } }, '{ sum(values: []) }')
    assert_result({ data: { names: 'a,b' } }, '{ names(values: ["a", "b"]) }')
  end

  def test_inline_list_variable_default
    assert_result({ data: { sum: 3 } }, 'query($values: [Int!]! = [1, 2]) { sum(values: $values) }')
  end
end
