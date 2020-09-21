require 'minitest/autorun'
require 'minitest/reporters'
require 'rails-graphql'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

module GraphQL
  class TestCase < Minitest::Test
  end
end