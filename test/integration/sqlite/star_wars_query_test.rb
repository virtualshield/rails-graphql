require 'integration/config'

class Integration_SQLite_StarWarsQueryTest < GraphQL::IntegrationTestCase
  load_schema 'sqlite'

  SCHEMA = ::StartWarsSqliteSchema

  def test_query_factions
    faction = named_list('Alliance to Restore the Republic', 'Galactic Empire')
    assert_result({ data: { liteFactions: faction } }, <<~GQL)
      query AllFactions { liteFactions { name } }
    GQL
  end

  def test_query_single_faction
    assert_result({ data: { liteFaction: { name: 'Galactic Empire' } } }, <<~GQL)
      query FindEmpireFaction { liteFaction(id: "2") { name } }
    GQL
  end

  def test_base_with_faction
    faction = { name: 'Alliance to Restore the Republic' }
    base = { name: 'Yavin', planet: 'Yavin 4', faction: faction }
    assert_result({ data: { liteBase: base } }, <<~GQL)
      query YavinBaseAndFaction { liteBase(id: "1") { name planet faction { name } } }
    GQL
  end

  def test_faction_with_bases_and_ships
    ships = named_list('TIE Fighter', 'TIE Interceptor', 'Executor')
    bases = named_list('Death Star', 'Shield Generator', 'Headquarters')
    faction = { name: 'Galactic Empire', bases: bases, ships: ships }
    assert_result({ data: { liteFaction: faction } }, <<~GQL)
      query EmpireFleet { liteFaction(id: "2") { name bases { name } ships { name } } }
    GQL
  end

  def test_full_data
    ships1 = named_list('X-Wing', 'Y-Wing', 'A-Wing', 'Millenium Falcon', 'Home One')
    bases1 = named_list('Yavin', 'Echo Base', 'Secret Hideout')

    ships2 = named_list('TIE Fighter', 'TIE Interceptor', 'Executor')
    bases2 = named_list('Death Star', 'Shield Generator', 'Headquarters')

    factions = [
      { name: 'Alliance to Restore the Republic', bases: bases1, ships: ships1 },
      { name: 'Galactic Empire', bases: bases2, ships: ships2 },
    ]

    assert_result({ data: { liteFactions: factions } }, <<~GQL)
      query FullData { liteFactions { name bases { name } ships { name } } }
    GQL
  end

  def test_data_recusivity
    faction = { name: 'Galactic Empire' }
    bases = named_list('Death Star', 'Shield Generator', 'Headquarters', faction: faction.dup)
    faction[:bases] = bases

    assert_result({ data: { liteFaction: faction } }, <<~GQL)
      query EmpireFleet { liteFaction(id: "2") { name bases { name faction { name } } } }
    GQL
  end

  def test_factions_scoped_argument
    faction = named_list('Galactic Empire', 'Alliance to Restore the Republic')
    assert_result({ data: { liteFactions: faction } }, <<~GQL, args: { order: 'desc' })
      query AllFactions($order: String!) { liteFactions(order: $order) { name } }
    GQL
  end

  def test_bases_scoped_argument_with_default
    bases = named_list('Death Star', 'Echo Base', 'Headquarters', 'Secret Hideout',
      'Shield Generator', 'Yavin')

    assert_result({ data: { liteBases: bases.reverse } }, <<~GQL)
      query AllBases { liteBases { name } }
    GQL

    assert_result({ data: { liteBases: bases } }, <<~GQL, args: { order: 'asc' })
      query AllBases($order: String!) { liteBases(order: $order) { name } }
    GQL
  end
end
