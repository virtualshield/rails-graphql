require 'integration/config'
require 'integration/schemas/sqlite'

SQLiteRecord.connection.instance_eval do
  create_table 'nr_items', force: :cascade do |t|
    t.string 'name'
    t.string 'nickname', default: 'anon'
    t.string 'code', null: false
    t.string 'custom_attributes'
    t.datetime 'stamped_at', null: false, default: -> { 'CURRENT_TIMESTAMP' }
    t.integer 'status', null: false, default: 0
  end

  create_table 'nr_owners', force: :cascade do |t|
    t.string 'name'
  end

  create_table 'nr_parts', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'name'
    t.string 'color'
    t.integer 'level', null: false, default: 3
  end

  create_table 'nr_members', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'name'
  end

  create_table 'nr_late_members', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'name'
  end

  create_table 'nr_default_members', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'name'
  end

  create_table 'nr_tight_members', force: :cascade do |t|
    t.integer 'owner_id', null: false
    t.string 'name'
  end

  create_table 'nr_loose_members', force: :cascade do |t|
    t.integer 'owner_id'
    t.string 'name'
  end

  create_table 'nr_notes', force: :cascade do |t|
    t.string 'body'
    t.string 'noteable_type'
    t.integer 'noteable_id'
  end

  create_table 'nr_garages', force: :cascade do |t|
    t.string 'name'
  end

  create_table 'nr_lots', force: :cascade do |t|
    t.string 'name'
  end

  create_table 'nr_vehicles', force: :cascade do |t|
    t.string 'name'
    t.string 'type'
    t.integer 'garage_id'
    t.integer 'lot_id', null: false
  end
end

class NrItem < SQLiteRecord
  attribute :code, :string, default: 'std'
  enum :status, { draft: 0, active: 1 }

  def secret=(value)
    self.name = "secret=#{value.inspect}"
  end
end

class NrOwner < SQLiteRecord
  has_many :parts, class_name: 'NrPart', foreign_key: :owner_id

  accepts_nested_attributes_for :parts
end

class NrPart < SQLiteRecord; end

class NrMember < SQLiteRecord
  belongs_to :owner, class_name: 'NrOwner', foreign_key: :owner_id, optional: false
end

if ActiveRecord.respond_to?(:belongs_to_required_validates_foreign_key=)
  previous = ActiveRecord.belongs_to_required_validates_foreign_key
  ActiveRecord.belongs_to_required_validates_foreign_key = false
  class NrLateMember < SQLiteRecord
    belongs_to :owner, class_name: 'NrOwner', foreign_key: :owner_id, optional: false
  end
  ActiveRecord.belongs_to_required_validates_foreign_key = previous
end

class NrDefaultMember < SQLiteRecord
  self.belongs_to_required_by_default = true

  belongs_to :owner, class_name: 'NrOwner', foreign_key: :owner_id
end

class NrTightMember < SQLiteRecord
  belongs_to :owner, class_name: 'NrOwner', foreign_key: :owner_id, optional: false
end

class NrLooseMember < SQLiteRecord
  belongs_to :owner, class_name: 'NrOwner', foreign_key: :owner_id, optional: true
end

class NrNote < SQLiteRecord
  belongs_to :noteable, polymorphic: true, optional: false
end

class NrGarage < SQLiteRecord; end
class NrLot < SQLiteRecord; end
class NrVehicle < SQLiteRecord; end

class NrCar < NrVehicle
  belongs_to :garage, class_name: 'NrGarage', foreign_key: :garage_id, optional: false
  belongs_to :lot, class_name: 'NrLot', foreign_key: :lot_id, optional: false
end

class Integration_SQLite_InputNullRulesTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :input_null_rules

    source NrItem do
      step(:input) { field(:secret, :string) }
    end

    source NrOwner
    source NrPart
    source NrMember
    source NrDefaultMember
    source NrLateMember if defined?(NrLateMember)
    source NrTightMember
    source NrLooseMember
    source NrNote
    source NrGarage
    source NrLot

    source NrVehicle do
      step(:input) { field(:type, :string) }
    end

    source NrCar do
      step(:object) { implements 'NrVehicle' }
    end
  end

  def test_a_null_for_a_nullable_column_is_written
    result = execute(<<~GQL, args: { data: { name: 'a', nickname: nil } })
      mutation($data: NrItemInput!) { createNrItem(nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_nil(NrItem.find_by(name: 'a').nickname)
    assert_equal('anon', NrItem.create!(name: 'b').nickname)
  ensure
    NrItem.delete_all
  end

  def test_a_null_for_a_column_with_a_default_function_is_left_out
    result = execute(<<~GQL, args: { data: { name: 'a', stamped_at: nil } })
      mutation($data: NrItemInput!) { createNrItem(nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    item = NrItem.find_by(name: 'a')
    refute_nil(item.stamped_at)

    result = execute(<<~GQL, args: { data: { name: 'b', stamped_at: nil } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['b', item.stamped_at], item.reload.values_at(:name, :stamped_at))
  ensure
    NrItem.delete_all
  end

  def test_a_null_for_a_column_that_cannot_be_null_is_left_out_without_a_database_default
    result = execute(<<~GQL, args: { data: { name: 'a', code: nil } })
      mutation($data: NrItemInput!) { createNrItem(nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    item = NrItem.find_by(name: 'a')
    assert_equal('std', item.code)

    item.update!(code: 'kept')
    result = execute(<<~GQL, args: { data: { name: 'b', code: nil } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(%w[b kept], item.reload.values_at(:name, :code))
  ensure
    NrItem.delete_all
  end

  def test_a_null_for_the_foreign_key_of_an_optional_association_detaches_it
    owner = NrOwner.create!(name: 'o')
    member = NrLooseMember.create!(name: 'm', owner: owner)
    result = execute(<<~GQL, args: { data: { owner_id: nil } })
      mutation($data: NrLooseMemberInput!) { updateNrLooseMember(id: #{member.id}, nrLooseMember: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_nil(member.reload.owner_id)
  ensure
    NrLooseMember.delete_all
    NrOwner.delete_all
  end

  def test_a_null_for_the_primary_key_and_the_inheritance_column_is_left_out
    car = NrCar.create!(name: 'c', garage: NrGarage.create!(name: 'g'), lot: NrLot.create!(name: 'l'))
    result = execute(<<~GQL, args: { data: { id: nil, type: nil, name: 'd' } })
      mutation($data: NrVehicleInput!) { updateNrVehicle(id: #{car.id}, nrVehicle: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['d', 'NrCar'], car.reload.values_at(:name, :type))
    assert_instance_of(NrCar, NrVehicle.find(car.id))
  ensure
    NrVehicle.delete_all
    NrGarage.delete_all
    NrLot.delete_all
  end

  def test_a_null_for_the_foreign_key_of_a_required_association_is_left_out
    assert_required_foreign_key_left_out(NrMember, 'NrMember', 'nrMember')
  end

  def test_a_null_for_the_foreign_key_of_an_association_required_by_default_is_left_out
    assert_nil(NrDefaultMember.reflect_on_association(:owner).options[:optional])
    assert_required_foreign_key_left_out(NrDefaultMember, 'NrDefaultMember', 'nrDefaultMember')
  end

  def test_a_null_for_the_foreign_key_of_a_required_association_is_left_out_under_a_conditional_validator
    skip('Rails does not have belongs_to_required_validates_foreign_key') unless defined?(NrLateMember)
    assert_equal(%i[message if], NrLateMember._validators[:owner].first.options.keys)
    assert_required_foreign_key_left_out(NrLateMember, 'NrLateMember', 'nrLateMember')
  end

  def test_a_null_for_a_required_foreign_key_that_cannot_be_null_is_left_out
    owner = NrOwner.create!(name: 'o')
    member = NrTightMember.create!(name: 'm', owner: owner)
    result = execute(<<~GQL, args: { data: { name: 'm2', owner_id: nil } })
      mutation($data: NrTightMemberInput!) { updateNrTightMember(id: #{member.id}, nrTightMember: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['m2', owner.id], member.reload.values_at(:name, :owner_id))
  ensure
    NrTightMember.delete_all
    NrOwner.delete_all
  end

  def test_a_null_for_the_type_of_a_required_polymorphic_association_is_left_out
    owner = NrOwner.create!(name: 'o')
    other = NrOwner.create!(name: 'p')
    note = NrNote.create!(body: 'b', noteable: owner)

    result = execute(<<~GQL, args: { data: { body: 'c', noteable_type: nil } })
      mutation($data: NrNoteInput!) { updateNrNote(id: #{note.id}, nrNote: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['c', 'NrOwner', owner.id], note.reload.values_at(:body, :noteable_type, :noteable_id))

    result = execute(<<~GQL, args: { data: { noteable_type: nil, noteable_id: other.id } })
      mutation($data: NrNoteInput!) { updateNrNote(id: #{note.id}, nrNote: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['NrOwner', other.id], note.reload.values_at(:noteable_type, :noteable_id))
  ensure
    NrNote.delete_all
    NrOwner.delete_all
  end

  def test_a_subclass_association_is_not_seen_through_the_base_source
    car = NrCar.create!(name: 'c', garage: NrGarage.create!(name: 'g'), lot: NrLot.create!(name: 'l'))

    result = execute(<<~GQL, args: { data: { name: 'd', lot_id: nil } })
      mutation($data: NrVehicleInput!) { updateNrVehicle(id: #{car.id}, nrVehicle: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['d', car.lot_id], car.reload.values_at(:name, :lot_id))

    result = execute(<<~GQL, args: { data: { name: 'e', garage_id: nil } })
      mutation($data: NrVehicleInput!) { updateNrVehicle(id: #{car.id}, nrVehicle: $data) { id } }
    GQL
    assert_match(/Garage must exist/, result['errors'].first['message'])
    assert_equal(['d', car.garage_id], car.reload.values_at(:name, :garage_id))
  ensure
    NrVehicle.delete_all
    NrGarage.delete_all
    NrLot.delete_all
  end

  def test_a_nested_null_follows_the_nested_column
    result = execute(<<~GQL, args: { data: { name: 'o', parts_attributes: [{ name: 'a', color: nil, level: nil }] } })
      mutation($data: NrOwnerInput!) { createNrOwner(nrOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    owner = NrOwner.find_by(name: 'o')
    part = owner.parts.first
    assert_equal(['a', nil, 3], part.values_at(:name, :color, :level))

    part.update!(color: 'red', level: 7)
    result = execute(<<~GQL, args: { data: { parts_attributes: [{ id: part.id, name: 'b', color: nil, level: nil }] } })
      mutation($data: NrOwnerInput!) { updateNrOwner(id: #{owner.id}, nrOwner: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['b', nil, 7], part.reload.values_at(:name, :color, :level))
  ensure
    NrPart.delete_all
    NrOwner.delete_all
  end

  def test_a_null_for_a_plain_column_named_attributes_is_written
    item = NrItem.create!(name: 'a', custom_attributes: 'keep')
    result = execute(<<~GQL, args: { data: { custom_attributes: nil } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_nil(item.reload.custom_attributes)
  ensure
    NrItem.delete_all
  end

  def test_a_null_for_a_field_backed_by_a_writer_is_left_out
    item = NrItem.create!(name: 'a')
    result = execute(<<~GQL, args: { data: { name: 'x', secret: nil } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('x', item.reload.name)

    result = execute(<<~GQL, args: { data: { secret: 'k' } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('secret="k"', item.reload.name)
  ensure
    NrItem.delete_all
  end

  def test_an_update_whose_params_end_up_empty_touches_nothing
    item = NrItem.create!(name: 'a')
    result = execute(<<~GQL, args: { data: { secret: nil } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal('a', item.reload.name)
  ensure
    NrItem.delete_all
  end

  def test_an_enum_column_with_a_database_default_can_be_omitted
    result = execute(<<~GQL, args: { data: { name: 'e' } })
      mutation($data: NrItemInput!) { createNrItem(nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    item = NrItem.find_by(name: 'e')
    assert_equal('draft', item.status)

    item.update!(status: 'active')
    result = execute(<<~GQL, args: { data: { name: 'f' } })
      mutation($data: NrItemInput!) { updateNrItem(id: #{item.id}, nrItem: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(%w[f active], item.reload.values_at(:name, :status))
  ensure
    NrItem.delete_all
  end

  private

    def assert_required_foreign_key_left_out(model, type_name, argument)
      owner = NrOwner.create!(name: 'o')
      member = model.create!(name: 'm', owner: owner)
      result = execute(<<~GQL, args: { data: { name: 'm2', owner_id: nil } })
        mutation($data: #{type_name}Input!) { update#{type_name}(id: #{member.id}, #{argument}: $data) { id } }
      GQL
      assert_nil(result['errors'])
      assert_equal(['m2', owner.id], member.reload.values_at(:name, :owner_id))

      [{ name: 'n', owner_id: nil }, { name: 'n' }].each do |data|
        result = execute(<<~GQL, args: { data: data })
          mutation($data: #{type_name}Input!) { create#{type_name}(#{argument}: $data) { id } }
        GQL
        assert_match(/Owner must exist/, result['errors'].first['message'])
      end
      assert_nil(model.find_by(name: 'n'))
    ensure
      model.delete_all
      NrOwner.delete_all
    end
end
