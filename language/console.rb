#!/usr/bin/env ruby
require 'pathname'

require 'pry'
require 'irb'
require 'rails'
require 'active_support/json'
Rails.const_set('GraphQL', Module.new)

load Pathname.new(__dir__).join('graphql-exec.rb').to_s

INTROSPECTION = Pathname.new(__dir__).join('introspection.gql').read

def p_introspection
  Rails::GraphQL::Parser.parse(INTROSPECTION)
end

require 'graphql'

ARGV.clear
IRB.start
