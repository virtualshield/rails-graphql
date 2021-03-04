require 'integration/config'

# See: https://github.com/graphql/graphql-js/blob/master/src/__tests__/starWarsQuery-test.js
class Integration_Memory_StarWarsQueryTest < GraphQL::IntegrationTestCase
  load_schema 'memory'

  SCHEMA = ::StartWarsMemSchema
  ALL_EPISODES = %w[NEW_HOPE EMPIRE JEDI]

  def test_r2d2_saga_hero
    assert_result({ data: { hero: { name: 'R2-D2' } } }, <<~GQL)
      query HeroNameQuery { hero { name } }
    GQL
  end

  def test_r2d2_by_id_and_friends
    friends = named_list('Luke Skywalker', 'Han Solo', 'Leia Organa')
    hero = { id: '2001', name: 'R2-D2', friends: friends }
    assert_result({ data: { hero: hero } }, <<~GQL)
      query HeroNameAndFriendsQuery {
        hero { id name friends { name } }
      }
    GQL
  end

  def test_r2d2_friends_of_friends
    friends1 = named_list('Han Solo', 'Leia Organa', 'C-3PO', 'R2-D2')
    friends2 = named_list('Luke Skywalker', 'Leia Organa', 'R2-D2')
    friends3 = named_list('Luke Skywalker', 'Han Solo', 'C-3PO', 'R2-D2')
    friends = [
      { name: 'Luke Skywalker', appearsIn: ALL_EPISODES, friends: friends1 },
      { name: 'Han Solo',       appearsIn: ALL_EPISODES, friends: friends2 },
      { name: 'Leia Organa',    appearsIn: ALL_EPISODES, friends: friends3 },
    ]

    hero = { name: 'R2-D2', friends: friends }
    assert_result({ data: { hero: hero } }, <<~GQL)
      query NestedQuery {
        hero { name friends { name appearsIn friends { name } } }
      }
    GQL
  end

  def test_using_ids_refetch
    human = { name: 'Luke Skywalker' }
    droid = { name: 'C-3PO' }

    assert_result({ data: { human: human, droid: droid } }, <<~GQL)
      query FetchLukeAndC3POQuery {
        human(id: "1000") { name }
        droid(id: "2000") { name }
      }
    GQL
  end

  def test_generic_query_fetch_by_id_luke
    xargs = { args: { some_id: '1000' } }
    assert_result({ data: { human: { name: 'Luke Skywalker' } } }, <<~GQL, **xargs)
      query FetchSomeIDQuery($someId: ID!) {
        human(id: $someId) { name }
      }
    GQL
  end

  def test_generic_query_fetch_by_id_han
    xargs = { args: { some_id: '1002' } }
    assert_result({ data: { human: { name: 'Han Solo' } } }, <<~GQL, **xargs)
      query FetchSomeIDQuery($someId: ID!) {
        human(id: $someId) { name }
      }
    GQL
  end

  def test_generic_query_fetch_by_id_invalid
    xargs = { args: { id: 'not a valid id' } }
    assert_result({ data: { human: nil } }, <<~GQL, **xargs)
      query FetchSomeIDQuery($id: ID!) {
        human(id: $id) { name }
      }
    GQL
  end

  def test_using_alias_to_change_key_name
    assert_result({ data: { luke: { name: 'Luke Skywalker' } } }, <<~GQL)
      query FetchLukeAliased { luke: human(id: "1000") { name } }
    GQL
  end

  def test_using_alias_to_change_key_name_on_array
    friends = [
      { name: 'Han Solo' },
      { name: 'Leia Organa' },
      { name: 'C-3PO' },
      { name: 'R2-D2' },
    ]

    assert_result({ data: { luke: { name: 'Luke Skywalker', others: friends } } }, <<~GQL)
      query FetchLukeDeepAliased { luke: human(id: "1000") {
        name others: friends { name }
      } }
    GQL
  end

  def test_using_alias_to_change_key_name_twice
    luke = { name: 'Luke Skywalker' }
    leia = { name: 'Leia Organa' }
    assert_result({ data: { luke: luke, leia: leia } }, <<~GQL)
      query FetchLukeAliased {
        luke: human(id: "1000") { name }
        leia: human(id: "1003") { name }
      }
    GQL
  end

  def test_query_with_duplicated_content
    luke = { name: 'Luke Skywalker', homePlanet: 'Tatooine' }
    leia = { name: 'Leia Organa', homePlanet: 'Alderaan' }
    assert_result({ data: { luke: luke, leia: leia } }, <<~GQL)
      query DuplicateFields {
        luke: human(id: "1000") { name homePlanet }
        leia: human(id: "1003") { name homePlanet }
      }
    GQL
  end

  def test_query_with_fragment
    luke = { name: 'Luke Skywalker', homePlanet: 'Tatooine' }
    leia = { name: 'Leia Organa', homePlanet: 'Alderaan' }
    assert_result({ data: { luke: luke, leia: leia } }, <<~GQL)
      query DuplicateFields {
        luke: human(id: "1000") { ...HumanFragment }
        leia: human(id: "1003") { ...HumanFragment }
      }

      fragment HumanFragment on Human {
        name
        homePlanet
      }
    GQL
  end

  def test_get_typename_field
    assert_result({ data: { hero: { __typename: 'Droid', name: 'R2-D2' } } }, <<~GQL)
      query CheckTypeOfR2 { hero { __typename name } }
    GQL
  end

  def test_get_typename_from_luke
    luke = { __typename: 'Human', name: 'Luke Skywalker' }
    assert_result({ data: { hero: luke } }, <<~GQL)
      query CheckTypeOfLuke { hero(episode: EMPIRE) { __typename name } }
    GQL
  end

  def test_error_on_secret_backstory
    hero = { name: 'R2-D2', secretBackstory: nil }
    errors = [{
      message: 'Secret backstory is secret',
      locations: [{ line: 1, column: 35 }, { line: 1, column: 50 }],
      path: %w[HeroNameQuery hero secretBackstory],
      extensions: { exception: 'RuntimeError' },
    }]

    assert_result({ data: { hero: hero }, errors: errors }, <<~GQL)
      query HeroNameQuery { hero { name secretBackstory } }
    GQL
  end

  def test_nested_secret_backstory
    friends = named_list('Luke Skywalker', 'Han Solo', 'Leia Organa', secretBackstory: nil)
    hero = { name: 'R2-D2', friends: friends }
    errors = 3.times.map do |n|
      {
        message: 'Secret backstory is secret',
        locations: [{ line: 1, column: 50 }, { line: 1, column: 65 }],
        path: ['HeroNameQuery', 'hero', 'friends', n, 'secretBackstory'],
        extensions: { exception: 'RuntimeError' },
      }
    end

    assert_result({ data: { hero: hero }, errors: errors }, <<~GQL)
      query HeroNameQuery { hero { name friends { name secretBackstory } } }
    GQL
  end

  def test_backstory_on_alias
    hero = { name: 'R2-D2', story: nil }
    errors = [{
      message: 'Secret backstory is secret',
      locations: [{ line: 1, column: 35 }, { line: 1, column: 57 }],
      path: %w[HeroNameQuery hero story],
      extensions: { exception: 'RuntimeError' },
    }]

    assert_result({ data: { hero: hero }, errors: errors }, <<~GQL)
      query HeroNameQuery { hero { name story: secretBackstory } }
    GQL
  end
end
