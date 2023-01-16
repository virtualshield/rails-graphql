# frozen_string_literal: true

require 'rake/extensiontask'

gem_spec = Gem::Specification.load('rails-graphql.gemspec')
Rake::ExtensionTask.new(:gql_parser, gem_spec) do |ext|
  ext.name = 'gql_parser'
  ext.ext_dir = 'ext'
  ext.lib_dir = 'lib'
  ext.cross_compile = true
  ext.cross_platform = %w[x86-mingw32 x64-mingw32]
end
