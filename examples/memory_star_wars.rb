EPISODES = %w[new_hope empire jedi]

class Character
  attr_accessor :id, :name, :friends, :appears_in

  def initialize(**data)
    data.each { |k, v| send("#{k}=", v) }
  end

  def friends
    @friends.map do |id|
      STAR_WARS_DATA[:humans][id] || STAR_WARS_DATA[:droids][id]
    end
  end

  def appears_in
    @appears_in.map { |i| EPISODES[i] }
  end

  def secret_backstory
    raise 'Secret backstory is secret'
  end
end

class Human < Character
  attr_accessor :home_planet
end

class Droid < Character
  attr_accessor :primary_function
end

STAR_WARS_DATA = {
  humans: {
    '1000' => Human.new(
      id: '1000',
      name: 'Luke Skywalker',
      friends: ['1002', '1003', '2000', '2001'],
      appears_in: [0, 1, 2],
      home_planet: 'Tatooine'
    ),
    '1001' => Human.new(
      id: '1001',
      name: 'Darth Vader',
      friends: ['1004'],
      appears_in: [0, 1, 2],
      home_planet: 'Tatooine'
    ),
    '1002' => Human.new(
      id: '1002',
      name: 'Han Solo',
      friends: ['1000', '1003', '2001'],
      appears_in: [0, 1, 2]
    ),
    '1003' => Human.new(
      id: '1003',
      name: 'Leia Organa',
      friends: ['1000', '1002', '2000', '2001'],
      appears_in: [0, 1, 2],
      home_planet: 'Alderaan'
    ),
    '1004' => Human.new(
      id: '1004',
      name: 'Wilhuff Tarkin',
      friends: ['1001'],
      appears_in: [0]
    ),
  },
  droids: {
    '2000' => Droid.new(
      id: '2000',
      name: 'C-3PO',
      friends: ['1000', '1002', '1003', '2001'],
      appears_in: [0, 1, 2],
      primary_function: 'Protocol'
    ),
    '2001' => Droid.new(
      id: '2001',
      name: 'R2-D2',
      friends: ['1000', '1002', '1003'],
      appears_in: [0, 1, 2],
      primary_function: 'Astromech'
    ),
  },
}

class ApplicationSchema < GraphQL::Schema
  disable_introspection!

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
    field :hero, 'Character', method_name: :find_hero,
      arguments: arg(:episode, 'Episode', desc: 'Return for a specific episode'),
      desc: 'Find the hero of the whole saga'

    field :human, 'Human', method_name: :find_human,
      arguments: arg(:id, :id, null: false, desc: 'ID of the human'),
      desc: 'Find a human character'

    field :droid, 'Droid', method_name: :find_droid,
      arguments: arg(:id, :id, null: false, desc: 'ID of the droid'),
      desc: 'Find a droid character'
  end

  def find_hero
    arguments.episode == 'empire' \
      ? STAR_WARS_DATA[:humans]['1000'] \
      : STAR_WARS_DATA[:droids]['2001']
  end

  def find_human
    STAR_WARS_DATA[:humans][arguments.id]
  end

  def find_droid
    STAR_WARS_DATA[:droids][arguments.id]
  end
end
