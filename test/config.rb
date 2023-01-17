require 'simplecov'
SimpleCov.start do
  coverage_criterion :branch

  add_filter '/test/'

  add_group 'Definition', ['/graphql/type', '/graphql/directive']
  add_group 'Field', ['/graphql/alternative', '/graphql/field']
  add_group 'Helpers', '/graphql/helpers'
  add_group 'Rails', '/graphql/railties'
  add_group 'Request', ['/graphql/collectors', '/graphql/request']
  add_group 'Subscription', '/graphql/subscription'
  add_group 'Source', ['/graphql/adapters', '/graphql/source']
end

require 'minitest/autorun'
require 'minitest/reporters'
require 'active_record'
require 'rails-graphql'
require 'debug'

$config = Rails::GraphQL.config
$config.logger = ActiveSupport::TaggedLogging.new(Logger.new('/dev/null'))
Rails::GraphQL::Request::Backtrace.skip_base_class = NilClass

# ActiveRecord::Base.logger = Logger.new(STDOUT)

require_relative './test_ext'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

# Load all files for coverage insurance
Rails::GraphQL.eager_load!

module GraphQL
  class TestCase < Minitest::Test
    PASSTHROUGH = ->(x, *) { x }
    PASSALLTHROUGH = ->(*x) { x }

    delegate :unmapped_class, to: :class

    protected

      def self.unmapped_class(*args)
        Class.new(*args) { def self.register!(*); end }
      end

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
