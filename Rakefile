# frozen_string_literal: true
# Rake tasks for development purposes

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'
require 'rake/testtask'
require 'rake/extensiontask'

require_relative 'test/config'

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.warning = true
  t.verbose = true
  t.test_files = Dir.glob("test/cases/**/*_test.rb")
end

gem_spec = Gem::Specification.load('rails-graphql.gemspec')
Rake::ExtensionTask.new(:libgraphqlparser, gem_spec) do |ext|
  ext.name = 'libgraphqlparser'
  ext.ext_dir = 'ext'
  ext.lib_dir = 'lib/libgraphqlparser'
  ext.cross_compile = true
  ext.cross_platform = %w[x86-mingw32 x64-mingw32]

  # Link C++ stdlib statically when building binary gems.
  ext.cross_config_options << '--enable-static-stdlib'
  ext.cross_config_options << '--disable-march-tune-native'

  ext.cross_compiling do |spec|
    spec.files.reject! { |path| File.fnmatch?('ext/*', path) }
  end
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Rails::GraphQL'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

