require 'integration/config'

class Integration_AlternativeTest < GraphQL::IntegrationTestCase
  module Alternatives
    # A regular field that is imported into an object
    class SampleField < GraphQL::Field
      define_field :sample, :string

      def resolve
        "#{current[:sample]} Resolved"
      end
    end

    # A simple query field that can called directly
    class SampleQuery < GraphQL::Query
      define_field :sample_query, :string

      def resolve
        'Sample Query'
      end
    end

    # A simple mutation field that can called directly
    class SampleMutation < GraphQL::Mutation
      define_field :sample_mutation, :string

      def perform
        request.extensions['mutation'] = 'Ok!'
      end

      def resolve
        'Sample Mutation'
      end
    end

    # A set of query fields
    class SampleQuerySet < GraphQL::QuerySet
      field :sample_query_a, :string
      field :sample_query_b, :string

      def sample_query_a
        'Sample Query A'
      end

      def sample_query_b
        'Sample Query B'
      end
    end

    # A set of mutation fields
    class SampleMutationSet < GraphQL::MutationSet
      field :sample_mutation_a, :string
      field :sample_mutation_b, :string

      def sample_mutation_a!
        request.extensions['mutationA'] = 'Ok!'
      end

      def sample_mutation_a
        'Sample Mutation A'
      end

      def sample_mutation_b!
        request.extensions['mutationB'] = 'Ok!'
      end

      def sample_mutation_b
        'Sample Mutation B'
      end
    end
  end

  class SCHEMA < GraphQL::Schema
    namespace :alternatives

    configure do |config|
      config.enable_string_collector = false
      config.default_response_format = :json
    end

    object 'Sample' do
      import Alternatives::SampleField
    end

    query_fields do
      import Alternatives::SampleQuery
      import Alternatives::SampleQuerySet
      field :sample_object, 'Sample'
    end

    mutation_fields do
      import Alternatives::SampleMutation
      import Alternatives::SampleMutationSet
    end

    def sample_object
      { sample: 'Sample Field' }
    end
  end

  def test_query_object
    result = { data: { sampleObject: { sample: 'Sample Field Resolved' } } }
    assert_result(result, '{ sampleObject { sample } }')
  end

  def test_query_field
    assert_result({ data: { sampleQuery: 'Sample Query' } }, '{ sampleQuery }')
  end

  def test_query_field_set
    assert_result({ data: { sampleQueryA: 'Sample Query A' } }, '{ sampleQueryA }')
    assert_result({ data: { sampleQueryB: 'Sample Query B' } }, '{ sampleQueryB }')

    result = { data: { sampleQueryA: 'Sample Query A', sampleQueryB: 'Sample Query B' } }
    assert_result(result, '{ sampleQueryA sampleQueryB }')
  end

  def test_mutation_field
    result = { data: { sampleMutation: 'Sample Mutation' }, extensions: { mutation: 'Ok!' } }
    assert_result(result, 'mutation { sampleMutation }')
  end

  def test_mutation_field_set
    result = { data: { sampleMutationA: 'Sample Mutation A' }, extensions: { mutationA: 'Ok!' } }
    assert_result(result, 'mutation { sampleMutationA }')

    result = { data: { sampleMutationB: 'Sample Mutation B' }, extensions: { mutationB: 'Ok!' } }
    assert_result(result, 'mutation { sampleMutationB }')

    result = {
      data: { sampleMutationA: 'Sample Mutation A', sampleMutationB: 'Sample Mutation B' },
      extensions: { mutationA: 'Ok!', mutationB: 'Ok!' },
    }

    assert_result(result, 'mutation { sampleMutationA sampleMutationB }')
  end

  def test_gql_introspection
    result = SCHEMA.to_gql
    expected = gql_file('alternative').split('').sort.join.squish

    # File.write('test/assets/alternative.gql', result)
    assert_equal(expected, result.split('').sort.join.squish)
  end
end
