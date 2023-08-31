require 'active_record'

puts '****************************************************'
puts ENV.inspect

class MySQLRecord < ActiveRecord::Base
  self.abstract_class = true

  establish_connection(
    name: 'mysql',
    adapter: 'mysql2',
    host: ENV.fetch('GQL_MYSQL_HOST', '127.0.0.1'),
    database: ENV.fetch('GQL_MYSQL_DATABASE', 'starwars'),
    username: ENV.fetch('GQL_MYSQL_USERNAME', 'root'),
    password: ENV['GQL_MYSQL_PASSWORD'],
    port: ENV.fetch('GQL_MYSQL_PORT', '3306'),
  )
end

MySQLRecord.connection.instance_eval do
  create_table 'jedi_types', force: :cascade do |t|
    t.string 'name'
  end

  create_table 'jedis', force: :cascade do |t|
    t.integer 'jedi_type_id'
    t.string 'name'
  end
end

class JediType < MySQLRecord
  has_many :jedi, class_name: 'Jedi', foreign_key: :jedi_type_id

  accepts_nested_attributes_for :jedi

  MASTER = create!(name: 'Master')
  PADAWAN = create!(name: 'Padawan')
end

class Jedi < MySQLRecord
  belongs_to :jedi_type, class_name: 'JediType', foreign_key: :jedi_type_id

  validates :name, presence: true, if: -> { true }

  create!(name: 'Ioda',             jedi_type: JediType::MASTER)
  create!(name: 'Obi-Wan Kenobi',   jedi_type: JediType::MASTER)
  create!(name: 'Anakin Skywalker', jedi_type: JediType::PADAWAN)
  create!(name: 'Mace Windu',       jedi_type: JediType::MASTER)
end

class StartWarsMySQLSchema < GraphQL::Schema
  namespace :star_wars_mysql

  configure do |config|
    config.enable_string_collector = false
    config.default_response_format = :json
  end

  source JediType do
    with_options on: 'jediTypes' do
      scoped_argument(:order) { |o| order(name: o) }
    end
  end

  source Jedi
end
