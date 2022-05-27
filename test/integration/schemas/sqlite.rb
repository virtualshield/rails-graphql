require 'active_record'
require 'active_record/database_configurations'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular 'base', 'bases'
end

class SQLiteRecord < ActiveRecord::Base
  self.abstract_class = true

  establish_connection(adapter: 'sqlite3', database: ':memory:')
end

SQLiteRecord.connection.instance_eval do
  create_table 'lite_factions', force: :cascade do |t|
    t.string 'name'
  end

  create_table 'lite_bases', force: :cascade do |t|
    t.integer 'faction_id'
    t.string 'name'
    t.string 'planet'
  end

  create_table 'lite_ships', force: :cascade do |t|
    t.integer 'faction_id'
    t.string 'name'
  end
end

class LiteFaction < SQLiteRecord
  has_many :bases, class_name: 'LiteBase', foreign_key: :faction_id
  has_many :ships, class_name: 'LiteShip', foreign_key: :faction_id

  accepts_nested_attributes_for :bases
  accepts_nested_attributes_for :ships

  REBELS = create!(name: 'Alliance to Restore the Republic')
  EMPIRE = create!(name: 'Galactic Empire')
end

class LiteBase < SQLiteRecord
  belongs_to :faction, class_name: 'LiteFaction', foreign_key: :faction_id

  validates :name, presence: true

  create!(name: 'Yavin',            planet: 'Yavin 4',   faction: LiteFaction::REBELS)
  create!(name: 'Echo Base',        planet: 'Hoth',      faction: LiteFaction::REBELS)
  create!(name: 'Secret Hideout',   planet: 'Dantooine', faction: LiteFaction::REBELS)
  create!(name: 'Death Star',       planet: nil,         faction: LiteFaction::EMPIRE)
  create!(name: 'Shield Generator', planet: 'Endor',     faction: LiteFaction::EMPIRE)
  create!(name: 'Headquarters',     planet: 'Coruscant', faction: LiteFaction::EMPIRE)
end

class LiteShip < SQLiteRecord
  belongs_to :faction, class_name: 'LiteFaction', foreign_key: :faction_id

  validates :name, presence: true, if: -> { true }

  create!(name: 'X-Wing',           faction: LiteFaction::REBELS)
  create!(name: 'Y-Wing',           faction: LiteFaction::REBELS)
  create!(name: 'A-Wing',           faction: LiteFaction::REBELS)
  create!(name: 'Millenium Falcon', faction: LiteFaction::REBELS)
  create!(name: 'Home One',         faction: LiteFaction::REBELS)
  create!(name: 'TIE Fighter',      faction: LiteFaction::EMPIRE)
  create!(name: 'TIE Interceptor',  faction: LiteFaction::EMPIRE)
  create!(name: 'Executor',         faction: LiteFaction::EMPIRE)
end

class StartWarsSqliteSchema < GraphQL::Schema
  namespace :star_wars_sqlite

  configure do |config|
    config.enable_string_collector = false
    config.default_response_format = :json
  end

  source LiteFaction do
    with_options on: 'liteFactions' do
      scoped_argument(:order) { |o| order(name: o) }
    end
  end

  source LiteBase do
    with_options on: 'liteBases' do
      scoped_argument(:order, default: :desc) { |o| order(name: o) }
    end
  end

  source LiteShip
end
