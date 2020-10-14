require 'minitest/autorun'
require 'minitest/reporters'
require 'rails-graphql'
require 'pry'

require_relative './test_ext'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

module GraphQL
  class TestCase < Minitest::Test
    PASSTHROUGH = ->(x, *) { x }
    PASSALLTHROUGH = ->(*x) { x }

    protected

      def passthrough
        PASSTHROUGH
      end

      def passallthrough
        PASSALLTHROUGH
      end

      def double(base = Object.new, **xargs)
        base.tap do |result|
          xargs.each do |key, value|
            block = value.is_a?(Proc) && value.lambda? ? value : ->(*) { value }
            result.define_singleton_method(key, &block)
          end
        end
      end

      def fake_directive
        result = Object.new
        result.define_singleton_method(:new) { |**xargs| xargs }
        result
      end

      def fake_type_map(pass = :fetch!, *others)
        double(**others.unshift(pass).map { |m| [m, passthrough] }.to_h)
      end

      def stubbed_type_map(*others, &block)
        Rails::GraphQL.stub(:type_map, fake_type_map(*others), &block)
      end

      def stubbed_config(name, value = nil, &block)
        Rails::GraphQL.config.stub(name, value, &block)
      end

      def stubbed_directives_to_set(&block)
        mocked = ->(directives, *) { directives }
        Rails::GraphQL.stub(:directives_to_set, mocked, &block)
      end
  end
end
