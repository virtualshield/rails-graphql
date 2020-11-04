require 'integration/config'

class Integration_SQLite_StarWarsMutationTest < GraphQL::IntegrationTestCase
  load_schema 'sqlite'

  SCHEMA = ::StartWarsSqliteSchema

  def test_can_create_faction
    args = { data: { name: 'Aliens' } }
    record = { id: next_id, name: 'Aliens' }
    assert_result({ data: { record: record } }, <<~GQL, args: args)
      mutation($data: LiteFactionInput!) {
        record: createLiteFaction(liteFaction: $data) { id name }
      }
    GQL

    assert_equal(3, LiteFaction.count)
    assert_equal('Aliens', LiteFaction.last.name)
    LiteFaction.last.destroy!
  end

  def test_can_update_faction
    args = { id: '1', data: { name: 'ARR' } }
    record = { id: '1', name: 'ARR' }
    assert_result({ data: { record: record } }, <<~GQL, args: args)
      mutation($id: ID!, $data: LiteFactionInput!) {
        record: updateLiteFaction(id: $id, liteFaction: $data) { id name }
      }
    GQL

    assert_equal('ARR', LiteFaction.find(1).name)
    LiteFaction.find(1).update(name: 'Alliance to Restore the Republic')
  end

  def test_can_create_and_delete_faction
    args = { data: { name: 'Should not Exist' } }
    record = { id: next_id, name: 'Should not Exist' }
    assert_result({ data: { record: record } }, <<~GQL, args: args)
      mutation($data: LiteFactionInput!) {
        record: createLiteFaction(liteFaction: $data) { id name }
      }
    GQL

    assert_equal(3, LiteFaction.count)
    assert_equal('Should not Exist', LiteFaction.last.name)

    assert_result({ data: { record: true } }, <<~GQL, args: { id: record[:id] })
      mutation($id: ID!) { record: deleteLiteFaction(id: $id) }
    GQL

    assert_equal(2, LiteFaction.count)
    refute_equal('Should not Exist', LiteFaction.last.name)
  end

  def test_can_create_faction_with_ships
    ships = [{ name: 'Alpha' }, { name: 'Delta' }]
    args = { data: { name: 'Emperor', ships_attributes: ships } }
    record = { id: next_id, name: 'Emperor', ships: ships }
    assert_result({ data: { record: record } }, <<~GQL, args: args)
      mutation($data: LiteFactionInput!) {
        record: createLiteFaction(liteFaction: $data) { id name ships { name } }
      }
    GQL

    assert_equal(3, LiteFaction.count)
    assert_equal('Emperor', LiteFaction.last.name)

    assert_equal(10, LiteShip.count)
    assert_equal(['Alpha', 'Delta'], LiteShip.last(2).map(&:name))

    LiteShip.last(2).map(&:destroy!)
    LiteFaction.last.destroy!
  end

  protected

    def next_id
      @@next_id ||= 2
      @@next_id += 1
      @@next_id.to_s
    end
end
