require 'config'

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

  protected

    def parse_execution(document)
      DESCRIBED_CLASS.parse_execution(document)
    end

    def assert_parser_error(token, document)
      error = assert_raises(DESCRIBED_CLASS::ParserError) { parse_execution(document) }
      assert_match(/\AParser error: unexpected "#{Regexp.escape(token)}" at \[\d+, \d+\]\z/, error.message)
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
