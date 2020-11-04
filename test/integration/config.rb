require 'config'

require 'active_support/core_ext/class/subclasses'

module GraphQL
  class IntegrationTestCase < TestCase
    SCHEMAS = Pathname.new(__dir__).join('schemas')
    ASSETS = Pathname.new(__dir__).join('../assets')

    def setup
      reset_type_map!
    end

    protected

      def self.load_schema(name)
        require(SCHEMAS.join("#{name}"))
      end

      def reset_type_map!
        Rails::GraphQL.type_map.hard_reset!
      end

      def named_list(*list, **extra)
        list.map { |x| extra.reverse_merge(name: x) }
      end

      def gql_file(name)
        ASSETS.join("#{name}.gql").read
      end

      def text_file(name)
        ASSETS.join("#{name}.txt").read
      end

      def json_file(name)
        JSON.parse(ASSETS.join("#{name}.json").read)
      end

      def execute(*args, **xargs)
        xargs[:as] ||= :object
        xargs[:schema] ||= self.class.const_get(:SCHEMA)
        ::GraphQL.execute(*args, **xargs)
      end

      def assert_result(obj, *args, dig: nil, **xargs)
        result = execute(*args, **xargs)
        result = result.try(:dig, *dig) if !!dig
        yield result if block_given?

        obj = obj.deep_stringify_keys if obj.is_a?(Hash)
        obj = obj.map(&:deep_stringify_keys) if obj.is_a?(Array)
        obj.nil? ? assert_nil(result) : assert_equal(obj, result)
      end
  end
end
