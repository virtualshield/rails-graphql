# frozen_string_literal: true
$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'rails/graphql/version'
require 'date'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'rails-graphql'
  s.version     = Rails::GraphQL::VERSION::STRING
  s.date        = Date.today.to_s
  s.authors     = ['Carlos Silva']
  s.email       = ['me@carlosfsilva.com']
  s.homepage    = 'https://github.com/virtualshield/rails-graphql'
  s.license     = 'MIT'
  s.summary     = 'A GraphQL server for Rails applications'
  s.description = 'A Fresh new GraphQL server for Rails applications, with a focus on natural and Ruby-like DSL'
  s.metadata    = {
    'homepage_uri'    => 'https://www.rails-graphql.dev/',
    "source_code_uri" => 'https://github.com/virtualshield/rails-graphql',
    'bug_tracker_uri' => 'https://github.com/virtualshield/rails-graphql/issues',
    # 'changelog_uri'   => 'https://github.com/virtualshield/rails-graphql/blob/master/CHANGELOG.md',
  }

  s.require_paths = ['lib']

  s.files        = Dir['MIT-LICENSE', 'README.rdoc', 'lib/**/*', 'ext/**/*', 'Rakefile']
  s.test_files   = Dir['test/**/*']
  s.extensions   = ['ext/extconf.rb']
  s.rdoc_options = ['--title', 'GraphQL server for Rails']

  s.required_ruby_version = '>= 2.6.3'
  s.add_dependency 'rails', '>= 5.0'

  s.add_development_dependency 'benchmark-ips', '~> 2.8.2'
  s.add_development_dependency 'minitest', '~> 5.14.0'
  s.add_development_dependency 'minitest-reporters', '~> 1.4.2'

  s.add_development_dependency 'rake-compiler', '~> 1.1.0'
  s.add_development_dependency 'rake-compiler-dock', '~> 1.0.1'

  s.add_development_dependency 'rdoc', '~> 6.4.0'
  s.add_development_dependency 'simplecov', '~> 0.20'

  s.add_development_dependency 'pg', '~> 1.3'
  s.add_development_dependency 'mysql2', '~> 0.5'
  s.add_development_dependency 'sqlite3', '~> 1.4'
end
