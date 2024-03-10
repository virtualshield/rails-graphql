require 'config'

class GQLParserTest < GraphQL::TestCase
  DESCRIBED_CLASS = GQLParser

  def test_parse_execution
    assert_parse_execution('{ hello }')
    assert_parse_execution(gql_file('introspection'))
    assert_parse_execution(<<~GQL)
      query AliasAfterDirective {
        query1 @paginate(limit: 10, id: "A")
        other: query1
      }
    GQL
  end

  def test_parse_type
    assert_equal(['Int', 0, 0], DESCRIBED_CLASS.parse_type('Int'))
    assert_equal(['Int', 0, 1], DESCRIBED_CLASS.parse_type('Int!'))
    assert_equal(['Int', 1, 0], DESCRIBED_CLASS.parse_type('[Int]'))
    assert_equal(['Int', 1, 1], DESCRIBED_CLASS.parse_type('[Int]!'))
    assert_equal(['Int', 1, 2], DESCRIBED_CLASS.parse_type('[Int!]'))
    assert_equal(['Int', 1, 3], DESCRIBED_CLASS.parse_type('[Int!]!'))
    assert_equal(['Int', 2, 0], DESCRIBED_CLASS.parse_type('[[Int]]'))
    assert_equal(['Int', 2, 4], DESCRIBED_CLASS.parse_type('[[Int!]]'))

    assert_equal(['String', 0, 0], DESCRIBED_CLASS.parse_type('String'))
    assert_equal(['Bool', 0, 0], DESCRIBED_CLASS.parse_type('Bool'))
    assert_equal(['Something', 0, 0], DESCRIBED_CLASS.parse_type('Something'))
  end

  def test_parse_arguments
    result = DESCRIBED_CLASS.parse_arguments('id: ID!')
    assert_equal(1, result.size)
    assert_equal(['id', ['ID', 0, 1], nil], result.first)

    result = DESCRIBED_CLASS.parse_arguments('name: String = "John"')
    assert_equal(1, result.size)
    assert_equal(['name', ['String', 0, 0], '"John"'], result.first)

    result = DESCRIBED_CLASS.parse_arguments('min: Bool = true, max: Bool = false')
    assert_equal(2, result.size)
    assert_equal(['min', ['Bool', 0, 0], true], result.first)
    assert_equal(['max', ['Bool', 0, 0], false], result.last)
  end

  protected

    def assert_parse_execution(content)
      assert(DESCRIBED_CLASS.parse_execution(content))
    end
end
