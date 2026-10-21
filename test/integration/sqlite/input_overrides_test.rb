require 'integration/config'
require 'integration/schemas/sqlite'

SQLiteRecord.connection.instance_eval do
  create_table 'ov_owners', force: :cascade do |t|
    t.string 'name'
    t.string 'region'
  end

  create_table 'ov_parts', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'name'
    t.string 'color'
  end

  create_table 'ov_profiles', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'bio'
    t.string 'theme'
  end

  create_table 'ov_shops', force: :cascade do |t|
    t.string 'name'
    t.string 'code'
  end

  create_table 'ov_stalls', force: :cascade do |t|
    t.string 'name'
    t.string 'code'
  end

  create_table 'ov_bases', force: :cascade do |t|
    t.string 'name'
    t.string 'internal_note'
    t.string 'flag', null: false, default: 'on'
  end

  create_table 'ov_plains', force: :cascade do |t|
    t.string 'name'
    t.string 'internal_note'
    t.string 'flag', null: false, default: 'on'
  end
end

class OvOwner < SQLiteRecord
  has_many :parts, class_name: 'OvPart', foreign_key: :owner_id
  has_one :profile, class_name: 'OvProfile', foreign_key: :owner_id

  accepts_nested_attributes_for :parts, reject_if: :all_blank
  accepts_nested_attributes_for :profile, update_only: true
end

class OvPart < SQLiteRecord; end
class OvProfile < SQLiteRecord; end

class OvShop < SQLiteRecord
  cattr_accessor :seen
end

class OvStall < SQLiteRecord; end
class OvBase < SQLiteRecord; end
class OvPlain < SQLiteRecord; end

class Integration_SQLite_InputOverridesTest < GraphQL::IntegrationTestCase
  class BaseInput < GraphQL::Input
    self.abstract = true

    def params
      super.except(:internal_note)
    end
  end

  class PlainInput < GraphQL::Input
    self.abstract = true
  end

  class SCHEMA < GraphQL::Schema
    namespace :input_overrides

    input 'OvProfile' do
      self.assigned_to = 'OvProfile'

      field(:id, :id)
      field(:bio, :string)
      field(:theme, :string, default: 'dark')
    end

    source OvPart do
      step(:input) { field(:color, :string, default: 'red') }
    end

    source OvOwner do
      step(:input) { field(:region, :string, default: 'north') }

      input_methods do
        def params
          super.tap do |params|
            params[:region] = 'computed' if params[:name] == 'compute'
            params[:parts_attributes]&.reject! { |part| part[:name] == 'skip' }
            params[:parts_attributes]&.each { |part| part[:color] = 'painted' if part[:name] == 'paint' }
          end
        end
      end
    end

    source OvShop do
      step(:input) do
        field(:notify, :boolean, default: true)
        field(:code, :string, default: 'NORTH')
      end

      input_methods do
        def params
          super.except(:notify).tap { |params| params[:code] = params[:code].downcase if params[:code] }
        end
      end

      def create_record
        OvShop.seen = input_argument.params
        super
      end
    end

    source OvStall do
      step(:input) { field(:code, :string, default: 'X') }

      input_methods do
        def params
          super.slice(:name)
        end
      end
    end

    source OvBase do
      self.input_class = BaseInput
    end

    source OvPlain do
      self.input_class = PlainInput
    end
  end

  def test_a_params_override_writing_a_defaulted_key_is_final
    owner = OvOwner.create!(name: 'o', region: 'south')
    result = execute(<<~GQL, args: { data: { name: 'compute', parts_attributes: [{ name: 'paint' }] } })
      mutation($data: OvOwnerInput!) { updateOvOwner(id: #{owner.id}, ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('computed', owner.reload.region)
    assert_equal([%w[paint painted]], owner.parts.pluck(:name, :color))

    result = execute(<<~GQL, args: { data: { name: 'compute', parts_attributes: [{ name: 'paint' }] } })
      mutation($data: OvOwnerInput!) { createOvOwner(ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    created = OvOwner.where(name: 'compute').where.not(id: owner.id).first
    assert_equal('computed', created.region)
    assert_equal([%w[paint painted]], created.parts.pluck(:name, :color))
  ensure
    OvPart.delete_all
    OvOwner.delete_all
  end

  def test_a_params_override_filtering_a_nested_list_is_final
    owner = OvOwner.create!(name: 'o')
    parts = [{ name: 'skip' }, { name: 'kept', color: 'blue' }]
    result = execute(<<~GQL, args: { data: { parts_attributes: parts } })
      mutation($data: OvOwnerInput!) { updateOvOwner(id: #{owner.id}, ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal([%w[kept blue]], owner.reload.parts.pluck(:name, :color))
  ensure
    OvPart.delete_all
    OvOwner.delete_all
  end

  def test_a_params_override_sees_the_declared_defaults_on_create_and_decides_them
    result = execute(<<~GQL, args: { data: { name: 's' } })
      mutation($data: OvShopInput!) { createOvShop(ovShop: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('north', OvShop.find_by(name: 's').code)
    assert_equal({ name: 's' }, OvShop.seen)

    result = execute(<<~GQL, args: { data: { name: 't', notify: false, code: 'SOUTH' } })
      mutation($data: OvShopInput!) { createOvShop(ovShop: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('south', OvShop.find_by(name: 't').code)
    assert_equal({ name: 't', code: 'south' }, OvShop.seen)
  ensure
    OvShop.delete_all
  end

  def test_a_params_override_can_whitelist_the_attributes
    built = SCHEMA.find_type!('OvStallInput').build(name: 'w', code: 'given')
    assert_equal({ name: 'w' }, built.params)
    assert_nil(built.resource.code)
    assert_nil(SCHEMA.find_type!('OvStallInput').build(name: 'x').resource.code)
  end

  def test_resource_extras_win_and_its_block_sees_the_provided_params
    input = SCHEMA.find_type!('OvStallInput')
    assert_equal('forced', input.build(name: 'w').resource(code: 'forced').code)

    built = input.build(name: 'w')
    record = built.resource { |stall| stall.code = built.params.keys.join(',') }
    assert_equal(%w[w name], record.values_at(:name, :code))
  end

  def test_a_custom_input_class_keeps_every_rule
    base = OvBase.create!(name: 'b', internal_note: 'keep', flag: 'off')
    result = execute(<<~GQL, args: { data: { name: 'c', internal_note: nil, flag: nil } })
      mutation($data: OvBaseInput!) { updateOvBase(id: #{base.id}, ovBase: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(%w[c keep off], base.reload.values_at(:name, :internal_note, :flag))

    result = execute(<<~GQL, args: { data: { internal_note: 'other' } })
      mutation($data: OvBaseInput!) { updateOvBase(id: #{base.id}, ovBase: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('keep', base.reload.internal_note)

    plain = OvPlain.create!(name: 'p', internal_note: 'keep', flag: 'off')
    result = execute(<<~GQL, args: { data: { name: 'q', internal_note: nil, flag: nil } })
      mutation($data: OvPlainInput!) { updateOvPlain(id: #{plain.id}, ovPlain: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['q', nil, 'off'], plain.reload.values_at(:name, :internal_note, :flag))
  ensure
    OvBase.delete_all
    OvPlain.delete_all
  end

  def test_a_hand_written_input_under_a_generated_one_follows_the_specification
    owner = OvOwner.create!(name: 'o', profile: OvProfile.new(bio: 'old', theme: 'light'))
    assert_equal('OvProfileInput', SCHEMA.find_type!('OvOwnerInput')[:profile_attributes].type_klass.gql_name)

    result = execute(<<~GQL, args: { data: { profile_attributes: { bio: 'new' } } })
      mutation($data: OvOwnerInput!) { updateOvOwner(id: #{owner.id}, ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(%w[new light], owner.profile.reload.values_at(:bio, :theme))

    result = execute(<<~GQL, args: { data: { profile_attributes: { theme: nil } } })
      mutation($data: OvOwnerInput!) { updateOvOwner(id: #{owner.id}, ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['new', nil], owner.profile.reload.values_at(:bio, :theme))

    result = execute(<<~GQL, args: { data: { name: 'fresh', profile_attributes: { bio: 'first' } } })
      mutation($data: OvOwnerInput!) { createOvOwner(ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['first', nil], OvOwner.find_by(name: 'fresh').profile.values_at(:bio, :theme))
  ensure
    OvProfile.delete_all
    OvOwner.delete_all
  end

  def test_reject_if_is_unchanged
    result = execute(<<~GQL, args: { data: { name: 'o', parts_attributes: [{ name: 'a' }, { name: nil }] } })
      mutation($data: OvOwnerInput!) { createOvOwner(ovOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['a'], OvOwner.find_by(name: 'o').parts.pluck(:name))
  ensure
    OvPart.delete_all
    OvOwner.delete_all
  end
end
