require 'config'
require 'timeout'

class GQLParserTest < GraphQL::TestCase
  DESCRIBED_CLASS = GQLParser

  def test_parse_execution_comment_ending_the_document
    [
      '#',
      '# only a comment',
      '{ a } #',
      '{ a } # trailing',
      "{ a }\n# trailing",
      "query A { a }\n# trailing",
      # A long document, which Ruby stores differently from a short one
      'query { a } fragment B on C { d } # trailing' + 'y' * 1000,
    ].each do |document|
      expected = locations(parse_execution(document + "\n"))
      assert_equal(expected, locations(parse_execution(with_bytes_after_end(document, "\n{ b }"))), document)
    end
  end

  def test_parse_execution_comment_with_a_nul_byte
    assert_equal(parse_execution('{ a }'), parse_execution("# x\0y\n{ a }"))
  end

  def test_parse_execution_string_ending_in_a_backslash
    assert_parser_error('"x\\', '{ a(b: "x\\')
    assert_parser_error('"x\\', with_bytes_after_end('{ a(b: "x\\', '") { c }'))

    # A long document, which Ruby stores differently from a short one
    value = 'a' * 1000
    assert_parser_error('"' + value + '\\', with_bytes_after_end('{ a(b: "' + value + '\\', '") { c }'))
  end

  def test_parse_execution_object_ending_after_a_string
    assert_parser_error('{c: "d"', '{ a(b: {c: "d"')
    assert_parser_error('{"c"', '{a(b:{"c"')

    document = with_bytes_after_end('{ a(b: {c: "d"', '}) }')
    assert_parser_error('{c: "d"', document)
  end

  def test_parse_execution_list_with_an_element_that_cannot_be_read
    [
      '{ a(b: [0]) }',
      '{ a(b: [-0]) }',
      '{ a(b: [1, 0]) }',
      '{ a(b: [[0]]) }',
      'query($v: [Int] = [0]) { a }',
    ].each { |document| assert_parse_returns_in_time(document) }
  end

  def test_parse_execution_operation_with_directives
    assert_equal(%w[a b], item_names(operation_fields('query Q @x { a b }')))
    assert_equal(%w[a], item_names(operation_fields('query Q @x @y(z: 1) { a }')))
    assert_parser_error('b', 'query Q @x b { a }')

    operations, fragments = parse_execution('query Q @x fragment F on T { a }')
    assert_equal([1, 1], [operations.size, fragments.size])

    operations, = parse_execution('query @x mutation { a }')
    assert_equal(%i[query mutation], operations.map(&:type))
  end

  def test_parse_execution_fragment_with_directives
    assert_equal(%w[d e], item_names(fragment_fields('fragment F on Q @x { d e }')))
    assert_parser_error('d', 'fragment F on Q @x d { e }')
  end

  def test_parse_execution_variable_with_directives
    assert_equal(%w[a b], item_names(operation_variables('query($a: Int @x $b: Int @y) { c }')))
    assert_equal(%w[a], item_names(operation_variables('query($a: Int @x) { c }')))
    assert_parser_error('b', 'query($a: Int @x b) { c }')
  end

  def test_parse_execution_field_with_directives
    assert_equal(%w[a b c], item_names(operation_fields('{ a @skip(if: false) b c }')))
    assert_equal(%w[a b c], item_names(operation_fields('{ a(x: 1) @skip(if: false) b c }')))
    assert_equal(%w[a b c], item_names(operation_fields('{ a @x @y b c }')))
    assert_equal(%w[a b c], item_names(operation_fields('{ a @skip(if: false) { x } b c }')))
    assert_equal(%w[b a], item_names(operation_fields('{ b a @x }')))
    assert_equal(%w[a c], item_names(operation_fields('{ a @x b: c }')))
    assert_equal(%w[a b], item_names(operation_fields('{ a @x b(c: 1) }')))
    assert_equal(%w[a b], item_names(operation_fields("{ a @x # c\n b }")))
    assert_parser_error('1', '{ a @include(if: true) 1 b }')

    assert_equal([1, 7], end_of(operation_fields('{ a @x }').first))
    assert_equal([1, 7], end_of(operation_fields("{ a @x\n}").first))
  end

  def test_parse_execution_spread_with_directives
    fragment = ' fragment F on Q { d }'
    assert_equal(%w[...F b c], item_names(operation_fields('{ ...F @include(if: true) b c }' + fragment)))
    assert_equal(%w[b ...F], item_names(operation_fields('{ b ...F @x }' + fragment)))
    assert_parser_error('1', '{ ...F @x 1 }' + fragment)
  end

  def test_parse_execution_inline_spread_with_directives
    assert_equal(['... on Q', 'b'], item_names(operation_fields('{ ... on Q @x { a } b }')))
    assert_equal(%w[a], item_names(spread_fields(operation_fields('{ ... @x { a } }').first)))
    assert_parser_error('b', '{ ... on Q @x b }')
  end

  def test_parse_execution_token_followed_by_a_comment
    assert_equal([1, 4], end_of(operation_fields("{ a # c\n}").first))
    assert_equal([1, 7], end_of(operation_fields("{ a @x # c\n}").first))
    assert_equal([1, 10], end_of(operation_fields("{ a(b: 1) # c\n b }").first))
    assert_equal([1, 4], end_of(operation_fields("{ a\n# c\n# d\n b }").first))
    assert_equal([1, 7], end_of(operation_fields("{ ...F # c\n b } fragment F on Q { d }").first))
    assert_equal([1, 17], end_of(operation_fields("{ ... on Q { a } # c\n b }").first))
    assert_equal([1, 18], end_of(operation_variables("query($a: Int = 1 # c\n) { b }").first))
  end

  protected

    def parse_execution(document)
      DESCRIBED_CLASS.parse_execution(document)
    end

    def assert_parser_error(token, document)
      error = assert_raises(DESCRIBED_CLASS::ParserError) { parse_execution(document) }
      assert_match(/\AParser error: unexpected "#{Regexp.escape(token)}" at \[\d+, \d+\]\z/, error.message)
    end

    def operation_fields(document)
      parse_execution(document).dig(0, 0, 4)
    end

    def operation_variables(document)
      parse_execution(document).dig(0, 0, 2)
    end

    def fragment_fields(document)
      parse_execution(document).dig(1, 0, 3)
    end

    def spread_fields(spread)
      spread[3]
    end

    def item_names(items)
      items.map do |item|
        next item[0].to_s unless item.of_type?(:spread)

        item[0] ? "...#{item[0]}" : "... on #{item[1]}"
      end
    end

    def end_of(token)
      [token.end_line, token.end_column]
    end

    def assert_parse_returns_in_time(document)
      Timeout.timeout(1) do
        parse_execution(document)
      rescue DESCRIBED_CLASS::ParserError
        nil
      end

      pass
    rescue Timeout::Error
      flunk("#{document.inspect} did not return within 1 second")
    end

    # Shortening a String in place keeps its old bytes after the new end (true of the Rubies the
    # project supports): the "?" becomes the terminator and +hidden+ follows it, without being part
    # of the document. On a Ruby that did not keep them, the assertions using this could not
    # reliably tell a parser that stops at the end of the document from one that does not
    def with_bytes_after_end(document, hidden)
      (+"#{document}?#{hidden}").tap { |value| value.slice!(document.length..) }
    end

    def locations(value)
      nested = value.respond_to?(:to_ary) ? value.to_ary.map { |item| locations(item) } : value
      return nested unless value.is_a?(DESCRIBED_CLASS::Token)

      [value.begin_line, value.begin_column, value.end_line, value.end_column, nested]
    end
end
