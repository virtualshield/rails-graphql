require 'integration/config'

class Integration_InputValuesTest < GraphQL::IntegrationTestCase
  Outfit = Struct.new(:name, :theme, :defaulted, :actor, keyword_init: true)

  class KeepDirective < GraphQL::Directive
    namespace :input_values
    placed_on :field
    rename! 'keep'

    argument(:keep_on, :boolean)
  end

  class NestedDirective < GraphQL::Directive
    namespace :input_values
    placed_on :field
    rename! 'nested'

    argument(:nested, 'NestedInput')
  end

  class SCHEMA < GraphQL::Schema
    namespace :input_values

    input 'SwitchesInput' do
      field(:send_summary, :boolean)
      field(:label, :string)
      field(:_secret_flag, :boolean)
    end

    input 'DefaultsInput' do
      field(:keep_on, :boolean, default: true)
      field(:label, :string, default: 'On')
      field(:note, :string)
    end

    enum 'Tone' do
      add 'WARM'
      add 'COLD'
    end

    input 'NestedInput' do
      field(:inner, 'DefaultsInput')
      field(:inners, 'DefaultsInput', array: true)
      field(:tone, 'Tone', default: 'WARM')
      field(:on, Rails::GraphQL::Type::Scalar::DateScalar)
      field(:meta, Rails::GraphQL::Type::Scalar::JsonScalar, default: { 'depth' => { 'n' => 1 } })
    end

    input 'DeepInput' do
      field(:deep, 'DefaultsInput', default: { keep_on: nil, note: 'x' })
    end

    input 'StrictInput' do
      field(:must, :string, null: false, default: 'x')
    end

    input 'OutfitInput' do
      self.assigned_to = 'Integration_InputValuesTest::Outfit'

      field(:name, :string)
      field(:theme, :string, default: 'dark')
      field(:defaulted, :int)
    end

    input 'MemoInput' do
      self.assigned_to = 'Integration_InputValuesTest::Outfit'

      field(:name, :string)
      field(:theme, :string, default: 'dark')
      field(:defaulted, :int)
      field(:actor, :string)

      attr_accessor :actor

      def params
        @params ||= super.merge(defaulted: defaulted_fields.size, actor: actor)
      end
    end

    query_fields do
      field(:echo, :string, arguments: argument(:switches, 'SwitchesInput', null: false))
        .resolve { |switches:| switches.to_h.map { |key, value| "#{key}=#{value.inspect}" }.join(',') }

      field(:defaults, :string, arguments: argument(:input, 'DefaultsInput', null: false))
        .resolve { |input:| input.to_h.map { |key, value| "#{key}=#{value.inspect}" }.join(',') }

      field(:defaulted, :string, arguments: argument(:input, 'DefaultsInput', null: false))
        .resolve { |input:| input.defaulted_fields.join(',') }

      field(:strict, :string, arguments: argument(:input, 'StrictInput', null: false))
        .resolve { |input:| input[:must] }

      field(:nested_echo, :string, arguments: argument(:input, 'NestedInput', null: false))
        .resolve { |input:| [input.to_h[:tone], input.to_h[:on]&.iso8601, input.defaulted_fields.join(',')].join(' ') }
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

  def test_missing_field_takes_its_default
    assert_result({ data: { defaults: 'keep_on=true,label="On"' } }, '{ defaults(input: {}) }')
    assert_result({ data: { defaults: 'keep_on=true,label="On",note="x"' } }, '{ defaults(input: { "note": "x" }) }')
    assert_result({ data: { defaults: 'keep_on=true,label="On"' } }, <<~GQL, args: { input: {} })
      query($input: DefaultsInput!) { defaults(input: $input) }
    GQL
  end

  def test_explicit_null_field_stays_null
    assert_result({ data: { defaults: 'keep_on=nil,label="On"' } }, '{ defaults(input: { "keepOn": null }) }')
    assert_result({ data: { defaults: 'keep_on=false,label=nil' } }, '{ defaults(input: { "keepOn": false, "label": null }) }')
    assert_result({ data: { defaults: 'keep_on=nil,label="On"' } }, <<~GQL, args: { input: { keepOn: nil } })
      query($input: DefaultsInput!) { defaults(input: $input) }
    GQL
  end

  def test_build_applies_defaults_to_missing_fields_only
    input = SCHEMA.find_type!('DefaultsInput')
    assert_equal({ keep_on: true, label: 'On' }, input.build.to_h)
    assert_equal({ keep_on: false, label: 'On' }, input.build(keep_on: false).to_h)
    assert_equal({ keep_on: nil, label: 'On' }, input.build(keepOn: nil).to_h)
    assert_equal({ keep_on: true, label: 'On', note: 'x' }, input.build(note: 'x').to_h)
    assert_equal(%i[keep_on label], input.build(note: 'x').defaulted_fields)
    assert_equal(%i[label], input.build(keep_on: nil).defaulted_fields)
  end

  def test_explicit_null_survives_a_round_trip
    input = SCHEMA.find_type!('DefaultsInput')
    built = input.build(keep_on: nil)
    assert_equal({ 'keepOn' => nil }, built.as_json)
    assert_equal({ keep_on: nil, label: 'On' }, input.deserialize(built.as_json).to_h)
    assert_equal(%i[label], input.deserialize(built.as_json).defaulted_fields)

    found = Rails::GraphQL::GlobalID.find(input.build(note: 'x').to_gid.to_s)
    assert_equal({ keep_on: true, label: 'On', note: 'x' }, found.to_h)
    assert_equal(%i[keep_on label], found.defaulted_fields)
  end

  def test_an_input_from_a_variable_default_knows_its_defaulted_fields
    assert_result({ data: { defaulted: 'keep_on,label' } }, <<~GQL)
      query($input: DefaultsInput! = { "note": "x" }) { defaulted(input: $input) }
    GQL

    assert_result({ data: { defaulted: 'label' } }, <<~GQL)
      query($input: DefaultsInput! = { "keepOn": null }) { defaulted(input: $input) }
    GQL
  end

  def test_false_directive_argument_arrives_as_false
    assert_equal({ keep_on: false }, KeepDirective.build(keepOn: false).args.to_h)
    assert_equal({ keep_on: false }, KeepDirective.build(keep_on: false).args.to_h)
  end

  def test_as_json_holds_an_explicit_null_at_every_level
    nested = SCHEMA.find_type!('NestedInput')
    built = nested.build(inner: { keep_on: nil }, inners: [{ label: nil }, nil])
    assert_equal({ 'inner' => { 'keepOn' => nil }, 'inners' => [{ 'label' => nil }, nil] }, built.as_json)

    again = nested.deserialize(built.as_json)
    assert_equal(%i[label], again.to_h[:inner].defaulted_fields)
    assert_equal(%i[tone meta], again.defaulted_fields)
  end

  def test_a_global_id_drops_every_null_and_keeps_the_defaulted_fields
    nested = SCHEMA.find_type!('NestedInput')

    found = Rails::GraphQL::GlobalID.find(nested.build(inner: { keep_on: nil, note: 'x' }, on: nil).to_gid.to_s)
    assert_equal({ keep_on: true, label: 'On', note: 'x' }, found.to_h[:inner].to_h)
    refute(found.to_h.key?(:on))
    assert_equal(%i[tone meta], found.defaulted_fields)

    found = Rails::GraphQL::GlobalID.find(nested.build(inner: { keep_on: nil }).to_gid.to_s)
    refute(found.to_h.key?(:inner))
  end

  def test_deserializing_an_instance_copies_its_provided_values
    nested = SCHEMA.find_type!('NestedInput')
    built = nested.build(inner: { note: 'x' }, tone: 'COLD', on: '2024-02-03')
    copy = nested.deserialize(built)

    assert(copy.to_h[:inner].equal?(built.to_h[:inner]))
    assert_equal(built.to_h[:tone], copy.to_h[:tone])
    assert_equal(Date.new(2024, 2, 3), copy.to_h[:on])
    assert_equal(%i[meta], built.defaulted_fields)
    assert_equal(%i[meta], copy.defaulted_fields)
  end

  def test_an_instance_given_as_a_variable_value_keeps_its_provided_fields
    input = SCHEMA.find_type!('DefaultsInput').build(keep_on: nil)
    assert_result({ data: { defaulted: 'label' } }, <<~GQL, args: { input: input })
      query($input: DefaultsInput!) { defaulted(input: $input) }
    GQL
    assert_result({ data: { defaults: 'keep_on=nil,label="On"' } }, <<~GQL, args: { input: input })
      query($input: DefaultsInput!) { defaults(input: $input) }
    GQL
  end

  def test_an_instance_with_a_defaulted_enum_or_date_is_accepted_as_a_variable_value
    nested = SCHEMA.find_type!('NestedInput')
    assert_result({ data: { nestedEcho: 'WARM 2024-02-03 tone,meta' } }, <<~GQL, args: { input: nested.build(on: '2024-02-03') })
      query($input: NestedInput!) { nestedEcho(input: $input) }
    GQL
    assert_result({ data: { nestedEcho: 'COLD  meta' } }, <<~GQL, args: { input: nested.build(tone: 'COLD') })
      query($input: NestedInput!) { nestedEcho(input: $input) }
    GQL
  end

  def test_a_directive_global_id_drops_a_nested_null_instead_of_turning_it_into_a_value
    found = Rails::GraphQL::GlobalID.find(NestedDirective.build(nested: { inner: { label: nil, note: 'n' } }).to_gid.to_s)
    inner = found.args.nested.to_h[:inner]
    assert_equal({ keep_on: true, label: 'On', note: 'n' }, inner.to_h)
    assert_equal(%i[keep_on label], inner.defaulted_fields)
  end

  def test_to_json_and_as_json_agree_on_the_provided_fields
    built = SCHEMA.find_type!('DefaultsInput').build(keep_on: nil, note: 'x')
    assert_equal({ 'keepOn' => nil, 'note' => 'x' }, built.as_json)
    assert_equal(built.as_json.to_json, built.to_json)
  end

  def test_an_explicit_null_for_a_non_null_field_with_a_default_is_refused
    refute_nil(execute('{ strict(input: { "must": null }) }')['errors'])
    assert_result({ data: { strict: 'x' } }, '{ strict(input: {}) }')
  end

  def test_a_directly_built_input_counts_every_value_as_provided
    built = SCHEMA.find_type!('OutfitInput').new(name: 'a', theme: nil)
    assert_equal([], built.defaulted_fields)
    assert_equal({ name: 'a', theme: nil }, built.params)
    assert_equal(Outfit.new(name: 'a', theme: nil), built.resource)

    assert_raises(Rails::GraphQL::InvalidValueError) { SCHEMA.find_type!('StrictInput').new(must: nil) }
  end

  def test_resource_applies_the_declared_defaults_and_params_does_not
    built = SCHEMA.find_type!('OutfitInput').build(name: 'a')
    assert_equal({ name: 'a' }, built.params)
    assert_equal(Outfit.new(name: 'a', theme: 'dark'), built.resource)
    assert_equal({ name: 'a' }, built.params)
  end

  def test_a_params_override_sees_the_state_set_on_the_instance_and_an_empty_defaulted_list
    built = SCHEMA.find_type!('MemoInput').build(name: 'a')
    built.actor = 'bob'
    assert_equal(Outfit.new(name: 'a', theme: 'dark', defaulted: 0, actor: 'bob'), built.resource)
    assert_equal({ name: 'a', defaulted: 1, actor: 'bob' }, built.params)
  end

  def test_a_memoized_params_override_read_before_the_resource_keeps_the_defaults_out
    built = SCHEMA.find_type!('MemoInput').build(name: 'a')
    assert_equal({ name: 'a', defaulted: 1, actor: nil }, built.params)
    assert_equal(Outfit.new(name: 'a', defaulted: 1), built.resource)
  end

  def test_a_declared_hash_default_is_copied_per_instance
    nested = SCHEMA.find_type!('NestedInput')
    nested.build.to_h[:meta]['depth']['n'] = 2
    nested.build.to_h[:meta]['extra'] = true
    assert_equal({ 'depth' => { 'n' => 1 } }, nested.build.to_h[:meta])
  end

  def test_a_null_inside_a_declared_default_is_introspected_as_null
    result = execute('{ __type(name: "DeepInput") { inputFields { name defaultValue } } }')
    fields = result.dig('data', '__type', 'inputFields').to_h { |field| field.values_at('name', 'defaultValue') }
    assert_match(/"keepOn":\s*null/, fields['deep'])
    assert_match(/"note":\s*"x"/, fields['deep'])
    refute_match(/label/, fields['deep'])
  end

  def test_a_directive_argument_typed_as_an_input_takes_the_declared_defaults
    nested = NestedDirective.build(nested: { on: '2024-02-03' }).args.nested
    assert_equal(%i[tone meta], nested.defaulted_fields)
    assert_equal('WARM', nested.to_h[:tone].to_s)
    assert_equal(Date.new(2024, 2, 3), nested.to_h[:on])
  end
end
