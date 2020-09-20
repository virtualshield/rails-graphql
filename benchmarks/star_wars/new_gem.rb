class StarWarsSchema < Rails::GraphQL::Schema
  enum 'Episode' do
    desc 'One of the films in the Star Wars Trilogy'

    add 'NEW_HOPE', desc: 'Released in 1977.'
    add 'EMPIRE',   desc: 'Released in 1980.'
    add 'JEDI',     desc: 'Released in 1983.'
  end

  interface 'Character' do
    desc 'A character in the Star Wars Trilogy'

    field :id, :id, null: false,
      desc: 'The id of the character'

    field :name, :string,
      desc: 'The name of the character'

    field :friends, 'Character', array: true, nullable: false,
      desc: 'The friends of the character, or an empty list if they have none'

    field :appears_in, 'Episode', array: true,
      desc: 'Which movies they appear in'

    field :secret_backstory, :string, disabled: true,
      desc: 'All secrets about their past'
  end

  object Human do
    implements 'Character'

    desc 'A humanoid creature in the Star Wars universe'

    change_field :id,
      desc: 'The id of the human'

    change_field :name,
      desc: 'The name of the human'

    change_field :friends,
      desc: 'The friends of the human, or an empty list if they have none'

    change_field :appears_in,
      desc: 'Which movies they appear in'

    change_field :secret_backstory,
      desc: 'Where are they from and how they came to be who they are'

    field :home_planet, :string,
      desc: 'The home planet of the human, or null if unknown'
  end

  object Droid do
    implements 'Character'

    desc 'A mechanical creature in the Star Wars universe'

    change_field :id,
      desc: 'The id of the droid'

    change_field :name,
      desc: 'The name of the droid'

    change_field :friends,
      desc: 'The friends of the droid, or an empty list if they have none'

    change_field :appears_in,
      desc: 'Which movies they appear in'

    change_field :secret_backstory,
      desc: 'Construction date and the name of the designer'

    field :primary_function, :string,
      desc: 'The primary function of the droid'
  end

  query_fields do
    field :human, 'Human', method_name: :find_human,
      arguments: arg(:id, :id, null: false, desc: 'ID of the human'),
      desc: 'Find a human character'

    field :droid, 'Droid', method_name: :find_droid,
      arguments: arg(:id, :id, null: false, desc: 'ID of the droid'),
      desc: 'Find a droid character'
  end

  def find_human(id:)
    STAR_WARS_DATA[:humans][id]
  end

  def find_droid(id:)
    STAR_WARS_DATA[:droids][id]
  end

  def self.execute(query, args, display: false)
    result = GraphQL.perform(query, args: args)
    puts result if display
  end
end
