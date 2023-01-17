require 'integration/config'

# See: https://github.com/graphql/graphql-js/blob/master/src/__tests__/starWarsIntrospection-test.js
class Integration_Memory_StarWarsIntrospectionTest < GraphQL::IntegrationTestCase
  load_schema 'memory'

  SCHEMA = ::StartWarsMemSchema

  def test_auto_introspection
    assert(SCHEMA.introspection?)
    assert(SCHEMA.has_field?(:query, :__schema))
    assert(SCHEMA.has_field?(:query, :__type))
  end

  def test_query_schema_types
    types = named_list(*%w[Boolean Character Droid Episode Float Human ID Int String
      _Mutation _Query __Directive __DirectiveLocation __EnumValue __Field __InputValue
      __Schema __Type __TypeKind])

    sort_items = ->(result) do
      result.dig('data', '__schema', 'types')&.sort_by! { |t| t['name'] }
    end

    assert_result({ data: { __schema: { types: types } } }, <<~GQL, &sort_items)
      { __schema { types { name } } }
    GQL
  end

  def test_query_schema_query_type
    assert_result({ data: { __schema: { queryType: { name: '_Query' } } } }, <<~GQL)
      { __schema { queryType { name } } }
    GQL
  end

  def test_query_schema_mutation_type
    assert_result({ data: { __schema: { mutationType: { name: '_Mutation' } } } }, <<~GQL)
      { __schema { mutationType { name } } }
    GQL
  end

  def test_query_specific_type
    assert_result({ data: { __type: { name: 'Droid' } } }, <<~GQL)
      { __type(name: "Droid") { name } }
    GQL
  end

  def test_query_specific_type_with_kind
    assert_result({ data: { __type: { name: 'Droid', kind: 'OBJECT' } } }, <<~GQL)
      { __type(name: "Droid") { name kind } }
    GQL
  end

  def test_query_specific_type_as_interface
    assert_result({ data: { __type: { name: 'Character', kind: 'INTERFACE' } } }, <<~GQL)
      { __type(name: "Character") { name kind } }
    GQL
  end

  def test_query_object_fields
    fields = [
      { name: 'id', type: { name: nil, kind: 'NON_NULL' } },
      { name: 'name', type: { name: 'String', kind: 'SCALAR' } },
      { name: 'friends', type: { name: nil, kind: 'LIST' } },
      { name: 'appearsIn', type: { name: nil, kind: 'LIST' } },
      { name: 'secretBackstory', type: { name: 'String', kind: 'SCALAR' } },
      { name: 'primaryFunction', type: { name: 'String', kind: 'SCALAR' } },
    ]

    assert_result({ data: { __type: { name: 'Droid', fields: fields } } }, <<~GQL)
      { __type(name: "Droid") { name fields { name type { name kind } } } }
    GQL
  end

  def test_query_object_fields_with_nested_type
    fields = [
      { name: 'id', type: { name: nil, kind: 'NON_NULL', ofType: { name: 'ID', kind: 'SCALAR' } } },
      { name: 'name', type: { name: 'String', kind: 'SCALAR', ofType: nil } },
      { name: 'friends', type: { name: nil, kind: 'LIST', ofType: { name: 'Character', kind: 'INTERFACE' } } },
      { name: 'appearsIn', type: { name: nil, kind: 'LIST', ofType: { name: 'Episode', kind: 'ENUM' } } },
      { name: 'secretBackstory', type: { name: 'String', kind: 'SCALAR', ofType: nil } },
      { name: 'primaryFunction', type: { name: 'String', kind: 'SCALAR', ofType: nil } },
    ]

    assert_result({ data: { __type: { name: 'Droid', fields: fields } } }, <<~GQL)
      {
        __type(name: "Droid") {
          name fields { name type { name kind ofType { name kind } } }
        }
      }
    GQL
  end

  def test_query_object_with_arguments
    name_arg = { name: 'name', description: nil, type: {
      name: nil, kind: 'NON_NULL', ofType: { name: 'String', kind: 'SCALAR' } ,
    }, defaultValue: nil }

    epi_arg = { name: 'episode', description: 'Return for a specific episode', type: {
      name: 'Episode', kind: 'ENUM', ofType: nil,
    }, defaultValue: nil }

    id_arg = { name: 'id', description: nil, type: {
      name: nil, kind: 'NON_NULL', ofType: { name: 'ID', kind: 'SCALAR' } ,
    }, defaultValue: nil }

    fields = [
      { name: 'hero', args: [epi_arg] },
      { name: 'human', args: [id_arg.merge(description: 'ID of the human')] },
      { name: 'droid', args: [id_arg.merge(description: 'ID of the droid')] },
    ]

    assert_result({ data: { __schema: { queryType: { fields: fields } } } }, <<~GQL)
      { __schema { queryType { fields {
        name
        args {
          name
          description
          type { name kind ofType { name kind } }
          defaultValue
        }
      } } } }
    GQL
  end

  def test_query_schema_documentation
    description = 'A mechanical creature in the Star Wars universe'
    assert_result({ data: { __type: { name: 'Droid', description: description } } }, <<~GQL)
      { __type(name: "Droid") { name description } }
    GQL
  end

  # There are some issues with the end sorting, so compare the string result
  # with sorted characters, which will produce the exact match
  def test_query_full_introspection
    SCHEMA.send(:enable_introspection!)

    query = gql_file('introspection')
    result = text_file('introspection-mem').split('').sort.join
    assert_result(result, query, as: :string) do |res|
      # File.write('test/assets/introspection-mem.txt', res)
      res.replace(res.split('').sort.join)
    end
  end

  def test_gql_introspection
    result = SCHEMA.to_gql
    expected = gql_file('mem').split('').sort.join.squish

    # File.write('test/assets/mem.gql', result)
    assert_equal(expected, result.split('').sort.join.squish)
  end
end
