# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'benchmark-memory', require: 'benchmark/memory'
  gem 'benchmark-ips', require: 'benchmark/ips'
  gem 'pry-byebug'

  gem 'rails', '>= 5.0'
  gem 'graphql'
  gem 'rails-graphql', path: '../'
end

require 'rails'
load(Pathname.new(__dir__).join("../tmp/star_wars.rb"))

DISPLAY = false
ARGS = { aid: '1000', bid: '2000' }
QUERY = <<~GQL
  query($aid: ID!, $bid: ID) {
    human(id: $aid) { ...data }
    droid(id: $bid) { ...data }
  }

  fragment data on Character {
    __typename
    id
    name
    appearsIn
    ... on Human {
      homePlanet
    }
    ... on Droid {
      primaryFunction
    }
    friends @include(if: true) {
      __typename
      id
      name
      appearsIn
      ... on Human {
        homePlanet
      }
      ... on Droid {
        primaryFunction
      }
    }
  }
GQL

ogem = -> do
  require 'graphql'
  require_relative 'star_wars/original_gem'
end

ngem = -> do
  require 'rails-graphql'
  require_relative 'star_wars/new_gem'

  Rails::GraphQL.eager_load!
  Rails::GraphQL.type_map.send(:register_pending!)
  Rails::GraphQL.config.logger = ActiveSupport::TaggedLogging.new(Logger.new('/dev/null'))
end

Benchmark.ips do |x|
  x.report('Original gem') { ogem.call; StarWars.execute(QUERY, ARGS, display: DISPLAY) }
  x.report('New gem') { ngem.call; StarWarsSchema.execute(QUERY, ARGS, display: DISPLAY) }
  x.compare!
end

# Benchmark.memory do |x|
#   x.report('Original gem') { ogem.call; StarWars.execute(QUERY, ARGS, display: DISPLAY) }
#   x.report('New gem') { ngem.call; StarWarsSchema.execute(QUERY, ARGS, display: DISPLAY) }
#   x.compare!
# end

# require 'memory_profiler'
# MemoryProfiler.report(allow_files: 'rails/graphql') do
#   StarWarsSchema.execute(QUERY, ARGS, display: DISPLAY)
# end.pretty_print
