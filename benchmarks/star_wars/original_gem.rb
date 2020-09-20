# frozen_string_literal: true

module StarWars
  class EpisodeEnum < GraphQL::Schema::Enum
    description 'One of the films in the Star Wars Trilogy'

    value 'NEW_HOPE', 'Released in 1977.'
    value 'EMPIRE',   'Released in 1980.'
    value 'JEDI',     'Released in 1983.'
  end

  module CharacterInterface
    include GraphQL::Schema::Interface

    graphql_name 'Character'
    description 'A character in the Star Wars Trilogy'

    field :id, ID, null: false,
      description: 'The id of the character'

    field :name, String, null: true,
      description: 'The name of the character'

    field :friends, [CharacterInterface], null: true,
      description: 'The friends of the character, or an empty list if they have none'

    field :appears_in, [EpisodeEnum], null: true,
      description: 'Which movies they appear in'

    definition_methods do
      def resolve_type(object, *)
        object.is_a?(::Human) ? HumanType : DroidType
      end
    end
  end

  class HumanType < GraphQL::Schema::Object
    implements CharacterInterface
    graphql_name 'Human'

    field :home_planet, String, null: true,
      description: 'The home planet of the human, or null if unknown'
  end

  class DroidType < GraphQL::Schema::Object
    implements CharacterInterface
    graphql_name 'Droid'

    field :primary_function, String, null: true,
      description: 'The primary function of the droid'
  end

  class QueryType < GraphQL::Schema::Object
    graphql_name 'Query'

    field :human, HumanType, null: false do
      argument :id, ID, required: true
    end

    field :droid, DroidType, null: false do
      argument :id, ID, required: true
    end

    def human(id:)
      STAR_WARS_DATA[:humans][id]
    end

    def droid(id:)
      STAR_WARS_DATA[:droids][id]
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
  end

  def self.execute(query, args, display: false)
    result = Schema.execute(query, variables: args).to_json
    puts result if display
  end
end
