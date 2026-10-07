require 'integration/config'

class Integration_InputValuesTest < GraphQL::IntegrationTestCase
  class KeepDirective < GraphQL::Directive
    namespace :input_values
    placed_on :field
    rename! 'keep'

    argument(:keep_on, :boolean)
  end

  class SCHEMA < GraphQL::Schema
    namespace :input_values

    input 'SwitchesInput' do
      field(:send_summary, :boolean)
      field(:label, :string)
    end

    query_fields do
      field(:echo, :string, arguments: argument(:switches, 'SwitchesInput', null: false))
        .resolve { |switches:| switches.to_h.map { |key, value| "#{key}=#{value.inspect}" }.join(',') }
    end
  end

  def test_false_field_arrives_as_false
    assert_result({ data: { echo: 'send_summary=false' } }, <<~GQL, args: { switches: { sendSummary: false } })
      query($switches: SwitchesInput!) { echo(switches: $switches) }
    GQL

    assert_result({ data: { echo: 'send_summary=false,label="Off"' } }, <<~GQL)
      { echo(switches: { "sendSummary": false, "label": "Off" }) }
    GQL
  end

  def test_false_directive_argument_arrives_as_false
    assert_equal({ keep_on: false }, KeepDirective.build(keepOn: false).args.to_h)
    assert_equal({ keep_on: false }, KeepDirective.build(keep_on: false).args.to_h)
  end
end
