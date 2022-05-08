require 'integration/config'

class Integration_ResolverPrecedenceTest < GraphQL::IntegrationTestCase
  EVENT_HANDLERS = { resolve: :@resolver, perform: :@performer }

  class SCHEMA < GraphQL::Schema
    namespace :precedence

    configure do |config|
      config.enable_string_collector = false
    end

    object 'Object1' do
      field(:field1, :string)
    end

    query_fields do
      field(:query1, :string)
      field(:query2, 'Object1').resolve { OpenStruct.new(field1: 'Default Value') }
    end

    mutation_fields do
      field(:mutation1, :string).perform { }
    end
  end

  attr_reader :object, :field

  def test_simple_query
    object = SCHEMA
    field = object[:query][:query1]

    # (1) Resolver as block comes first
    stub_handler(field, :resolve, -> { 'Ok 1' }) do
      assert_result('Ok 1', 'query1')
    end

    # (2) Method on schema comes second
    stub_callable(object, field, :query1, -> { 'Ok 2' }) do
      assert_result('Ok 2', 'query1')
    end

    # (1) Resolver block has higher precedence than method on schema
    stub_callable(object, field, :query1, -> { 'Nok 3' }) do
      stub_handler(field, :resolve, -> { 'Ok 3' }) do
        assert_result('Ok 3', 'query1')
      end
    end
  end

  def test_simple_mutation
    object = SCHEMA
    field = object[:mutation][:mutation1]

    # (1) With performer but no resolver has the higher precedence
    $check = true
    stub_handler(field, :perform, -> { 'Ok 1' }) do
      assert_result('Ok 1', 'mutation1', :mutation)
    end

    # (2) Performer first and then resolver has the second precedence
    result = ''
    stub_handler(field, :perform, -> { result << 'Ok 2' }) do
      stub_handler(field, :resolve, -> { result << 'Ok 3' }) do
        assert_result('Ok 2Ok 3', 'mutation1', :mutation)
      end
    end

    # (3) Performer as a method but resolver as block
    result = ''
    stub_callable(object, field, :mutation1!, -> { result << 'Ok 4' }) do
      stub_handler(field, :resolve, -> { result << 'Ok 5' }) do
        assert_result('Ok 4Ok 5', 'mutation1', :mutation)
      end
    end

    # (4) Performer as a method first and then resolve as a method
    result = ''
    stub_callable(object, field, :mutation1!, -> { result << 'Ok 6' }) do
      stub_callable(object, field, :mutation1, -> { result << 'Ok 7' }) do
        assert_result('Ok 6Ok 7', 'mutation1', :mutation)
      end
    end

    # (2) Blocks has higher precedence than methods
    result = ''
    stub_callable(object, field, :mutation1!, -> { result << 'Nok 8' }) do
      stub_callable(object, field, :mutation1, -> { result << 'Nok 9' }) do
        stub_handler(field, :perform, -> { result << 'Ok 8' }) do
          stub_handler(field, :resolve, -> { result << 'Ok 9' }) do
            assert_result('Ok 8Ok 9', 'mutation1', :mutation)
          end
        end
      end
    end
  end

  def test_simple_object
    object = GraphQL::Object1Object
    field = object[:field1]

    # (1) Block has higher precedence than default value
    stub_handler(field, :resolve, -> { 'Ok 1' }) do
      assert_result('Ok 1', 'field1.query2')
    end

    # (2) Method on object comes second
    stub_callable(object, field, :field1, -> { 'Ok 2' }) do
      assert_result('Ok 2', 'field1.query2')
    end

    # (3) Lastly it will simply put the original resolved value
    assert_result('Default Value', 'field1.query2')

    # (1) Block has higher precedence than methond on object
    stub_callable(object, field, :field1, -> { 'Nok 3' }) do
      stub_handler(field, :resolve, -> { 'Ok 3' }) do
        assert_result('Ok 3', 'field1.query2')
      end
    end
  end

  protected

    def assert_result(expected, field, operation = :query)
      doc, data = field.split('.').reduce(['', expected]) do |(d, r), part|
        ["{ #{part} #{d} }", { part => r }]
      end

      super({ data: data }, "#{operation} #{doc}")
    end

    def stub_handler(field, event, *args, **xargs)
      block = args.shift if args.first.is_a?(Proc)
      cb = create_callback(field, event, *args, **xargs, &block)

      field.get_reset_ivar(:@dynamic_resolver, event == :resolve) do
        field.stub_ivar(EVENT_HANDLERS[event], cb) { yield }
      end
    end

    def stub_callable(object, field, method_name, block)
      field.get_reset_ivar(:@dynamic_resolver) do
        field.get_reset_ivar(:@resolver) do
          object.stub_imethod(method_name, block) { yield }
        end
      end
    end

    def create_callback(source, event, *args, **xargs, &block)
      Rails::GraphQL::Callback.new(source, event, *args, **xargs, &block)
    end
end
