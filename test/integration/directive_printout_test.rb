require 'integration/config'

class Integration_DirectivePrintoutTest < GraphQL::IntegrationTestCase
  class FlagDirective < GraphQL::Directive
    namespace :directive_printout
    placed_on :field_definition
    rename! 'flag'

    argument :keep_on, :boolean
    argument :label, :string
  end

  class SCHEMA < GraphQL::Schema
    namespace :directive_printout

    query_fields do
      field(:only_false, :string, directives: FlagDirective.new(keep_on: false))
      field(:nil_then_value, :string, directives: FlagDirective.new(keep_on: nil, label: 'x'))
      field(:all_nil, :string, directives: FlagDirective.new(keep_on: nil))
      field(:unknown_key, :string, directives: FlagDirective.new(keepon: true))
    end
  end

  def test_false_argument_is_printed
    assert_includes(printout, 'onlyFalse: String @flag(keepOn: false)')
  end

  def test_no_comma_before_the_first_printed_argument
    assert_includes(printout, 'nilThenValue: String @flag(label: "x")')
  end

  def test_no_parentheses_without_a_printed_argument
    assert_includes(printout, "allNil: String @flag\n")
    assert_includes(printout, "unknownKey: String @flag\n")
  end

  def test_a_directive_instance_compiles_on_its_own
    assert_equal('@flag(keepOn: false)', ::GraphQL.to_gql(FlagDirective.new(keep_on: false)))
    assert_equal('@flag', ::GraphQL.to_gql(FlagDirective.new(keep_on: nil)))
  end

  private

    def printout
      Rails::GraphQL::ToGQL.describe(SCHEMA, with_descriptions: false)
    end
end
