require 'integration/config'
require 'integration/schemas/sqlite'

SQLiteRecord.connection.instance_eval do
  create_table 'lite_outposts', force: :cascade do |t|
    t.string 'name'
    t.string 'region'
    t.integer 'level', null: false, default: 3
  end

  create_table 'lite_profiles', force: :cascade do |t|
    t.integer 'outpost_id'
    t.string 'bio'
    t.string 'theme'
  end

  create_table 'lite_notes', force: :cascade do |t|
    t.string 'body'
    t.string 'noteable_type'
    t.integer 'noteable_id'
  end

  create_table 'lite_vehicles', force: :cascade do |t|
    t.string 'name'
    t.string 'type'
  end

  create_table 'lite_cards', force: :cascade do |t|
    t.integer 'vehicle_id'
    t.string 'title'
    t.string 'color'
  end
end

class LiteOutpost < SQLiteRecord
  attr_accessor :extra_attributes

  has_one :profile, class_name: 'LiteProfile', foreign_key: :outpost_id

  accepts_nested_attributes_for :profile, update_only: true
end

class LiteProfile < SQLiteRecord
  belongs_to :outpost, class_name: 'LiteOutpost', foreign_key: :outpost_id

  accepts_nested_attributes_for :outpost, update_only: true
end

class LiteNote < SQLiteRecord
  belongs_to :noteable, polymorphic: true, optional: true

  accepts_nested_attributes_for :noteable, update_only: true
end

class LiteVehicle < SQLiteRecord; end

class LiteCar < LiteVehicle
  has_one :card, class_name: 'LiteCard', foreign_key: :vehicle_id

  accepts_nested_attributes_for :card, update_only: true
end

class LiteCard < SQLiteRecord; end

class Integration_SQLite_StarWarsInputDefaultsTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :star_wars_input_defaults

    source LiteFaction

    source LiteOutpost do
      step(:input) { field(:region, :string, default: 'north') }

      input_methods do
        def resource
          super.tap { |outpost| outpost.name = outpost.name&.strip }
        end

        def params
          super.tap do |params|
            params[:profile_attributes]&.transform_values! { |value| value.is_a?(String) ? value.strip : value }
            params[:extra_attributes] = { source: 'api' }
          end
        end
      end
    end

    source LiteBase do
      step(:input) { field(:planet, :string, default: 'Nowhere') }
    end

    source LiteProfile do
      step(:input) { field(:theme, :string, default: 'dark') }

      # A custom step reading the input builds the record before create_record
      def create_record
        input_argument.resource
        super
      end
    end

    source LiteNote do
      step(:input) { field(:noteable_attributes, Rails::GraphQL::Type::Scalar::JsonScalar, null: true) }
    end

    source LiteVehicle do
      step(:input) do
        field(:type, :string)
        field(:card_attributes, 'LiteCardInput', null: true)
      end
    end

    source LiteCar do
      step(:object) { implements 'LiteVehicle' }
    end

    source LiteCard do
      step(:input) { field(:color, :string, default: 'red') }
    end
  end

  def test_update_applies_only_the_provided_attributes
    base = LiteBase.create!(name: 'Outpost', planet: 'Jakku', faction: LiteFaction::REBELS)

    assert_result({ data: { updateLiteBase: { name: 'Camp', planet: 'Jakku' } } }, <<~GQL)
      mutation { updateLiteBase(id: #{base.id}, liteBase: { "name": "Camp" }) { name planet } }
    GQL

    assert_result({ data: { updateLiteBase: { name: 'Camp', planet: nil } } }, <<~GQL)
      mutation { updateLiteBase(id: #{base.id}, liteBase: { "name": "Camp", "planet": null }) { name planet } }
    GQL
  ensure
    base&.destroy
  end

  def test_update_applies_only_the_provided_attributes_of_a_nested_record
    base = LiteBase.create!(name: 'Outpost', planet: 'Jakku', faction: LiteFaction::REBELS)

    bases = [{ id: base.id, name: 'Camp' }, { name: 'Fresh' }]
    result = execute(<<~GQL, args: { data: { bases_attributes: bases } })
      mutation($data: LiteFactionInput!) {
        updateLiteFaction(id: #{LiteFaction::REBELS.id}, liteFaction: $data) { id }
      }
    GQL

    assert_nil(result['errors'])
    assert_equal(['Camp', 'Jakku'], base.reload.values_at(:name, :planet))
    assert_nil(LiteBase.find_by(name: 'Fresh').planet)
  ensure
    LiteBase.where(name: %w[Outpost Camp Fresh]).destroy_all
  end

  def test_a_null_nested_attributes_field_leaves_the_association_alone
    before = LiteFaction::REBELS.bases.order(:id).pluck(:name, :planet)
    result = execute(<<~GQL, args: { data: { bases_attributes: nil } })
      mutation($data: LiteFactionInput!) {
        updateLiteFaction(id: #{LiteFaction::REBELS.id}, liteFaction: $data) { id }
      }
    GQL
    assert_nil(result['errors'])
    assert_equal(before, LiteFaction::REBELS.bases.order(:id).pluck(:name, :planet))

    result = execute(<<~GQL, args: { data: { name: 'Lone', profile_attributes: nil } })
      mutation($data: LiteOutpostInput!) { createLiteOutpost(liteOutpost: $data) { name region profile { bio } } }
    GQL
    assert_nil(result['errors'])
    assert_equal({ 'name' => 'Lone', 'region' => 'north', 'profile' => nil }, result.dig('data', 'createLiteOutpost'))
  ensure
    LiteOutpost.delete_all
  end

  def test_a_nested_record_found_through_its_foreign_key_keeps_its_attributes
    outpost = LiteOutpost.create!(name: 'Ridge', region: 'south')

    result = execute(<<~GQL, args: { data: { bio: 'new', outpost_id: outpost.id, outpost_attributes: { name: 'Renamed' } } })
      mutation($data: LiteProfileInput!) { createLiteProfile(liteProfile: $data) { outpost { name region } } }
    GQL
    assert_nil(result['errors'])
    assert_equal({ 'name' => 'Renamed', 'region' => 'south' }, result.dig('data', 'createLiteProfile', 'outpost'))
    assert_equal(1, LiteOutpost.count)
  ensure
    LiteProfile.delete_all
    LiteOutpost.delete_all
  end

  def test_an_association_that_only_updates_applies_only_the_provided_attributes
    outpost = LiteOutpost.create!(name: 'Ridge', profile: LiteProfile.new(bio: 'old', theme: 'light'))

    result = execute(<<~GQL, args: { data: { profile_attributes: { bio: 'new' } } })
      mutation($data: LiteOutpostInput!) {
        updateLiteOutpost(id: #{outpost.id}, liteOutpost: $data) { profile { bio theme } }
      }
    GQL
    assert_nil(result['errors'])
    assert_equal({ 'bio' => 'new', 'theme' => 'light' }, result.dig('data', 'updateLiteOutpost', 'profile'))
  ensure
    LiteProfile.delete_all
    LiteOutpost.delete_all
  end

  def test_a_nested_record_takes_no_declared_default
    result = execute(<<~GQL, args: { data: { name: 'Lone', profile_attributes: { bio: 'first' } } })
      mutation($data: LiteOutpostInput!) { createLiteOutpost(liteOutpost: $data) { region profile { bio theme } } }
    GQL
    assert_nil(result['errors'])
    assert_equal({ 'region' => 'north', 'profile' => { 'bio' => 'first', 'theme' => nil } }, result.dig('data', 'createLiteOutpost'))

    bare = LiteOutpost.create!(name: 'Bare')
    result = execute(<<~GQL, args: { data: { profile_attributes: { bio: 'second' } } })
      mutation($data: LiteOutpostInput!) {
        updateLiteOutpost(id: #{bare.id}, liteOutpost: $data) { profile { bio theme } }
      }
    GQL
    assert_nil(result['errors'])
    assert_equal({ 'bio' => 'second', 'theme' => nil }, result.dig('data', 'updateLiteOutpost', 'profile'))
  ensure
    LiteProfile.delete_all
    LiteOutpost.delete_all
  end

  def test_a_nested_attributes_field_that_is_not_an_input_object_is_passed_as_given
    outpost = LiteOutpost.create!(name: 'Ridge', region: 'south')
    note = LiteNote.create!(body: 'Hi', noteable: outpost)

    result = execute(<<~GQL, args: { data: { noteable_attributes: { name: 'Renamed' } } })
      mutation($data: LiteNoteInput!) { updateLiteNote(id: #{note.id}, liteNote: $data) { body } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['Renamed', 'south'], outpost.reload.values_at(:name, :region))

    result = execute(<<~GQL, args: { data: { body: 'Bye', noteable_attributes: nil } })
      mutation($data: LiteNoteInput!) { updateLiteNote(id: #{note.id}, liteNote: $data) { body } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['Renamed', 'south'], outpost.reload.values_at(:name, :region))
  ensure
    LiteNote.delete_all
    LiteOutpost.delete_all
  end

  def test_a_nested_record_of_a_subclass_takes_no_declared_default
    result = execute(<<~GQL, args: { data: { type: 'LiteCar', name: 'Racer', card_attributes: { title: 'Pass' } } })
      mutation($data: LiteVehicleInput!) { createLiteVehicle(liteVehicle: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['Pass', nil], LiteCard.first.values_at(:title, :color))

    result = execute(<<~GQL, args: { data: { type: 'LiteCar', name: 'Bare', card_attributes: nil } })
      mutation($data: LiteVehicleInput!) { createLiteVehicle(liteVehicle: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(1, LiteCard.count)
  ensure
    LiteCard.delete_all
    LiteVehicle.delete_all
  end

  def test_a_params_override_is_applied_to_the_nested_record
    result = execute(<<~GQL, args: { data: { name: 'Lone', profile_attributes: { bio: ' spaced ' } } })
      mutation($data: LiteOutpostInput!) { createLiteOutpost(liteOutpost: $data) { profile { bio theme } } }
    GQL
    assert_nil(result['errors'])
    assert_equal({ 'bio' => 'spaced', 'theme' => nil }, result.dig('data', 'createLiteOutpost', 'profile'))
  ensure
    LiteProfile.delete_all
    LiteOutpost.delete_all
  end

  def test_an_input_from_a_variable_default_applies_only_the_provided_fields
    outpost = LiteOutpost.create!(name: 'Ridge', region: 'south', profile: LiteProfile.new(bio: 'old', theme: 'light'))

    assert_result({ data: { updateLiteOutpost: { name: 'Camp', region: 'south' } } }, <<~GQL)
      mutation($data: LiteOutpostInput! = { "name": "Camp" }) {
        updateLiteOutpost(id: #{outpost.id}, liteOutpost: $data) { name region }
      }
    GQL

    assert_result({ data: { updateLiteOutpost: { profile: { bio: 'new', theme: 'light' } } } }, <<~GQL)
      mutation($data: LiteOutpostInput! = { "profileAttributes": { "bio": "new" } }) {
        updateLiteOutpost(id: #{outpost.id}, liteOutpost: $data) { profile { bio theme } }
      }
    GQL
  ensure
    LiteProfile.delete_all
    LiteOutpost.delete_all
  end

  def test_a_null_for_a_column_with_a_database_default_counts_as_not_provided
    result = execute(<<~GQL, args: { data: { name: 'Lone', level: nil } })
      mutation($data: LiteOutpostInput!) { createLiteOutpost(liteOutpost: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(3, LiteOutpost.find_by(name: 'Lone').level)

    outpost = LiteOutpost.create!(name: 'Ridge', level: 5)
    result = execute(<<~GQL, args: { data: { name: 'Camp', level: nil } })
      mutation($data: LiteOutpostInput!) { updateLiteOutpost(id: #{outpost.id}, liteOutpost: $data) { id } }
    GQL
    assert_nil(result['errors'])
    assert_equal(['Camp', 5], outpost.reload.values_at(:name, :level))
  ensure
    LiteOutpost.delete_all
  end

  def test_create_applies_the_declared_default
    result = execute(<<~GQL)
      mutation { createLiteBase(liteBase: { "name": "Fresh", "factionId": #{LiteFaction::REBELS.id} }) { id planet } }
    GQL
    assert_equal('Nowhere', result.dig('data', 'createLiteBase', 'planet'))
  ensure
    LiteBase.where(name: 'Fresh').destroy_all
  end
end
