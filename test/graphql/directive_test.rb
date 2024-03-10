require 'config'

class GraphQL_DirectiveTest < GraphQL::TestCase
  ARGUMENT_ERROR = Rails::GraphQL::ArgumentError

  def test_dynamic_argument
    sample_class = unmapped_class(Rails::GraphQL::Directive)
    sample_class.argument(:test, 'String')
    assert_equal(1, sample_class.arguments.size)

    sample_class = unmapped_class(Rails::GraphQL::Directive)
    sample_class.dynamic = true
    assert_raises(ARGUMENT_ERROR) { sample_class.argument(:test, 'String') }
    assert_raises(ARGUMENT_ERROR) { sample_class.ref_argument(1) }
  end
end
