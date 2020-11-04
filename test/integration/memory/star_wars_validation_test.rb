require 'integration/config'

# See: https://github.com/graphql/graphql-js/blob/master/src/__tests__/starWarsValidation-test.js
class Integration_Memory_StarWarsValidationTest < GraphQL::IntegrationTestCase
  load_schema 'memory'

  SCHEMA = ::StartWarsMemSchema

  def test_complex_but_valid_query
    assert_result(nil, <<~GQL, dig: 'errors')
      query NestedQueryWithFragment { hero {
        ...NameAndAppearances friends { ...NameAndAppearances friends {
          ...NameAndAppearances
        } }
      } }

      fragment NameAndAppearances on Character {
        name
        appearsIn
      }
    GQL
  end

  def test_invalid_query
    errors = [{
      message: 'syntax error, unexpected EOF',
      locations: [{ line: 2, column: 1 }],
    }]

    assert_result(errors, <<~GQL, dig: 'errors')
      query DroidFieldInFragment { hero { name ... on Droid { primaryFunction
    GQL
  end

  def test_nonexistent_fields
    errors = [{
      message: 'Unable to find a field named "favoriteSpaceship" on GraphQL::CharacterInterface.',
      locations: [{ line: 1, column: 35 }, { line: 1, column: 52 }],
      path: %w[HeroSpaceshipQuery hero favoriteSpaceship],
      extensions: { stage: 'organize', exception: 'Rails::GraphQL::MissingFieldError' },
    }]

    assert_result(errors, <<~GQL, dig: 'errors')
      query HeroSpaceshipQuery { hero { favoriteSpaceship } }
    GQL
  end

  def test_requires_fields
    errors = [{
      message: 'The "hero" was assigned to the Character which is not a leaf type and requires a selection of fields.',
      locations: [{ line: 1, column: 28 }, { line: 1, column: 32 }],
      path: %w[HeroSpaceshipQuery hero],
      extensions: { stage: 'organize', exception: 'Rails::GraphQL::FieldError' },
    }]

    assert_result(errors, <<~GQL, dig: 'errors')
      query HeroSpaceshipQuery { hero }
    GQL
  end

  def test_disallows_fields_on_scalars
    errors = [{
      message: 'The "name" was assigned to the String which is a leaf type and does not have nested fields.',
      locations: [{ line: 1, column: 35 }, { line: 1, column: 64 }],
      path: %w[HeroSpaceshipQuery hero name],
      extensions: { stage: 'organize', exception: 'Rails::GraphQL::FieldError' },
    }]

    assert_result(errors, <<~GQL, dig: 'errors')
      query HeroSpaceshipQuery { hero { name { firstCharacterOfName } } }
    GQL
  end

  def test_specific_fields_on_interfaces
    errors = [{
      message: 'Unable to find a field named "primaryFunction" on GraphQL::CharacterInterface.',
      locations: [{ line: 1, column: 40 }, { line: 1, column: 55 }],
      path: %w[HeroSpaceshipQuery hero primaryFunction],
      extensions: { stage: 'organize', exception: 'Rails::GraphQL::MissingFieldError' },
    }]

    assert_result(errors, <<~GQL, dig: 'errors')
      query HeroSpaceshipQuery { hero { name primaryFunction } }
    GQL
  end

  def test_allow_specific_fields_with_fragments
    assert_result(nil, <<~GQL, dig: 'errors')
      query DroidFieldInFragment { hero { name ...DroidFields } }
      fragment DroidFields on Droid { primaryFunction }
    GQL
  end

  def test_allow_specific_fields_with_spread
    assert_result(nil, <<~GQL, dig: 'errors')
      query DroidFieldInFragment { hero { name ... on Droid { primaryFunction } } }
    GQL
  end
end
