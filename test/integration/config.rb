require 'config'

require 'active_support/core_ext/class/subclasses'

module GraphQL
  class IntegrationTestCase < TestCase
    SCHEMAS = Pathname.new(__dir__).join('schemas')
    ASSETS = Pathname.new(__dir__).join('../assets')

    BASE_SCHEMA = ::Rails::GraphQL::Schema

    def run(*)
      BASE_SCHEMA.send(:introspection_dependencies!)
      BASE_SCHEMA.type_map.send(:load_dependencies!)

      super
    end

    def setup
      BASE_SCHEMA.type_map.base_classes.each do |base_class|
        GraphQL.const_get(base_class).descendants.each(&:register!)
      end

      index = BASE_SCHEMA.type_map.instance_variable_get(:@index)[:base][:Type]
      remove_keys_form_type_map&.each(&index.method(:delete))
    end

    def teardown
      BASE_SCHEMA.type_map.reset!
    end

    protected

      def self.load_schema(name)
        require(SCHEMAS.join("#{name}"))
      end

      def remove_keys_form_type_map
        all_non_spec_keys
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

      def all_non_spec_keys
        [
          :any, 'Any',
          :bigint, 'Bigint',
          :binary, 'Binary', :file,
          :date_time, 'DateTime', :datetime,
          :date, 'Date',
          :decimal, 'Decimal',
          :time, 'Time',
          :json, 'JSON',
        ]
      end
  end
end
