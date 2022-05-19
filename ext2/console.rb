#!/usr/bin/env ruby
require 'pathname'

require 'pry'
require 'irb'

puts 'Pre making'
system 'ruby gql_parser.rb'
puts 'Making'
system 'make'

puts 'Requiring'
require_relative './gql_parser.so'

# puts GQLParser.parse_execution("123")

ARGV.clear
IRB.start
