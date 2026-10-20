require 'integration/config'

class Integration_ListLiteralTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :list_literal

    query_fields do
      field(:sum, :int, null: false, arguments: argument(:values, :int, array: true, null: false, nullable: false))
        .resolve { |values:| values.sum }

      field(:names, :string, null: false, arguments: argument(:values, :string, array: true, null: false))
        .resolve { |values:| values.join(',') }

      field(:items, :string, null: false, arguments: argument(:values, :int, array: true, nullable: true))
        .resolve { |values:| values.inspect }

      field(:flags, :string, null: false, arguments: argument(:values, :boolean, array: true, nullable: true))
        .resolve { |values:| values.inspect }

      input('Box') { field(:a, :int) }
      field(:box, :string, null: false, arguments: argument(:value, 'BoxInput')).resolve { |value:| value[:a].inspect }
    end
  end

  def test_null_inside_an_inline_list
    assert_result({ data: { items: '[1, nil]' } }, '{ items(values: [1, null]) }')
    assert_result({ data: { items: '[nil]' } }, 'query($v: [Int] = [null]) { items(values: $v) }')
    assert_result({ data: { flags: '[true, nil]' } }, '{ flags(values: [true, null]) }')
    assert_result({ data: { flags: '[nil]' } }, 'query($v: [Boolean] = [null]) { flags(values: $v) }')
    assert_result({ data: { flags: '[false, nil]' } }, 'query($v: [Boolean]) { flags(values: $v) }', args: { v: [false, nil] })
  end

  def test_inline_list_given_to_an_input_object_argument_is_refused
    ['{ box(value: [1]) }', '{ box(value: []) }'].each do |document|
      result = execute(document)
      assert_includes(result['errors'].first['message'], 'Invalid value', document)
    end

    assert_result({ data: { box: '1' } }, '{ box(value: { "a": 1 }) }')
  end

  def test_invalid_inline_list_is_reported_as_written
    result = execute('{ sum(values: [1, "x"]) }')
    assert_includes(result['errors'].first['message'], 'Invalid value "[1, "x"]" provided to values argument on sum')

    result = execute('{ sum(values: [1, null]) }')
    assert_includes(result['errors'].first['message'], 'Invalid value "[1, null]" provided to values argument on sum')

    result = execute('query($v: [Int!]!) { sum(values: $v) }', args: { v: [1, 'x', nil] })
    assert_includes(result['errors'].first['message'], 'Invalid value "[1, "x", null]" provided to $v variable')

    result = execute('query($v: [Int!]!) { sum(values: $v) }', args: { v: [1, nil] })
    assert_includes(result['errors'].first['message'], 'Invalid value "[1, null]" provided to $v variable')
  end

  def test_invalid_list_variable_default_is_refused
    ['query($v: Int = [1]) { sum(values: [1]) }', 'query($v: [Int] = [1.5]) { sum(values: [1]) }',
     'query($v: [Int] = [true]) { sum(values: [1]) }', 'query($v: BoxInput = []) { sum(values: [1]) }'].each do |document|
      result = execute(document)
      assert_match(/The given default value .* is not valid for this argument/, result['errors'].first['message'], document)
    end

    assert_result({ data: { sum: 3 } }, 'query($v: [Int!]! = [1, 2]) { sum(values: $v) }')
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
