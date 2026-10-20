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
      field(:_secret_flag, :boolean)
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

  def test_a_field_given_under_both_spellings_is_invalid
    input = SCHEMA.find_type!('SwitchesInput')
    assert(input.valid_input?({ 'sendSummary' => false }))
    assert(input.valid_input?({ 'send_summary' => false }))
    refute(input.valid_input?({ 'sendSummary' => false, 'send_summary' => true }))
    refute(input.valid_input?({ 'send_summary' => true, 'sendSummary' => false }))
    refute(input.valid_input?({ 'SendSummary' => false }))

    query = 'query($switches: SwitchesInput!) { echo(switches: $switches) }'
    result = execute(query, args: { switches: { sendSummary: false, send_summary: true } })
    assert_nil(result['data']['echo'])
    assert_match(/Invalid value .* provided to \$switches variable/, result['errors'].first['message'])
  end

  def test_a_field_named_with_a_leading_underscore
    assert_result({ data: { echo: '_secret_flag=true' } }, '{ echo(switches: { "_secretFlag": true }) }')
    assert_result({ data: { echo: '_secret_flag=true' } }, <<~GQL, args: { switches: { _secret_flag: true } })
      query($switches: SwitchesInput!) { echo(switches: $switches) }
    GQL
  end

  def test_false_directive_argument_arrives_as_false
    assert_equal({ keep_on: false }, KeepDirective.build(keepOn: false).args.to_h)
    assert_equal({ keep_on: false }, KeepDirective.build(keep_on: false).args.to_h)
  end
end
