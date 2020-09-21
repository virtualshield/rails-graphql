# frozen_string_literal: true
# Rake tasks for development purposes

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'
require 'rake/testtask'

require_relative 'test/config'

require_relative 'tasks/libgraphqlparser'

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.warning = true
  t.verbose = true
  t.test_files = Dir.glob("test/graphql/**/*_test.rb")
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Rails::GraphQL'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

