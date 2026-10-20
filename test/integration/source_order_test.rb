require 'integration/config'
require 'integration/schemas/sqlite'

class Integration_SourceOrderTest < GraphQL::IntegrationTestCase
  class LateSource < GraphQL::Source::Base
    namespace :source_order_late

    step(:query) { field(:greeting, :string, null: false) }

    def greeting
      'Hello!'
    end
  end

  class EarlySchema < GraphQL::Schema
    namespace :source_order_early
  end

  class EarlySource < GraphQL::Source::Base
    namespace :source_order_early

    step(:query) { field(:greeting, :string, null: false) }

    def greeting
      'Hello!'
    end
  end

  class OtherSource < GraphQL::Source::Base
    namespace :source_order_other

    step(:query) { field(:greeting, :string, null: false) }

    def greeting
      'Hello!'
    end
  end

  class ConflictSource < GraphQL::Source::Base
    namespace :source_order_conflict

    step(:query) { field(:greeting, :string, null: false) }
  end

  class ImportedSource < GraphQL::Source::Base
    namespace :source_order_imported

    step(:query) { field(:greeting, :string, null: false) }

    def greeting
      'Hello!'
    end
  end

  class OtherConflictSource < GraphQL::Source::Base
    namespace :source_order_conflict

    step(:query) { field(:farewell, :string, null: false) }

    def farewell
      'Bye!'
    end
  end

  class TwoFieldsSource < GraphQL::Source::Base
    namespace :source_order_two_fields

    step(:query) do
      field(:greeting, :string, null: false)
      field(:farewell, :string, null: false)
    end

    def farewell
      'Bye!'
    end
  end

  class BlastSource < GraphQL::Source::Base
    namespace :source_order_blast

    step(:query) { field(:greeting, :string, null: false) }
  end

  class OtherBlastSource < GraphQL::Source::Base
    namespace :source_order_blast

    step(:query) { field(:farewell, :string, null: false) }

    def farewell
      'Bye!'
    end
  end

  class ChildSource < GraphQL::Source::Base
    namespace :source_order_child

    step(:query) { field(:greeting, :string, null: false) }

    def greeting
      'Hello!'
    end
  end

  class GoneSource < GraphQL::Source::Base
    namespace :source_order_gone

    step(:query) { field(:greeting, :string, null: false) }
  end

  def test_base_schema_does_not_take_the_fields_of_another_namespace
    OtherSource.build_query
    base = Class.new(GraphQL::Schema)
    other = Class.new(GraphQL::Schema) { namespace :source_order_other }

    assert_result({ data: { greeting: 'Hello!' } }, '{ greeting }', schema: other)
    refute(base.query_field?(:greeting))
  ensure
    base&.unregister!
  end

  def test_schema_field_with_the_same_name_as_a_late_source_field
    ConflictSource.build_query
    OtherConflictSource.build_query
    schema = Class.new(GraphQL::Schema) do
      namespace :source_order_conflict
      query_fields { field(:greeting, :string).resolve { 'Mine!' } }
    end

    assert_raises(Rails::GraphQL::DuplicatedError) { execute('{ greeting }', schema: schema) }
    assert_raises(Rails::GraphQL::DuplicatedError) { execute('{ farewell }', schema: schema) }
    assert(schema.query_field?(:farewell))
  end

  def test_the_other_fields_of_a_late_source_with_a_conflict_are_attached
    TwoFieldsSource.build_query
    schema = Class.new(GraphQL::Schema) do
      namespace :source_order_two_fields
      query_fields { field(:greeting, :string).resolve { 'Mine!' } }
    end

    first = assert_raises(Rails::GraphQL::DuplicatedError) { execute('{ farewell }', schema: schema) }
    second = assert_raises(Rails::GraphQL::DuplicatedError) { execute('{ farewell }', schema: schema) }
    refute_same(first, second)
    assert_match(/greeting.*TwoFieldsSource/m, first.message)
    assert(schema.query_field?(:farewell))
  end

  def test_a_conflict_in_one_late_source_does_not_interrupt_another
    BlastSource.build_query
    schema = Class.new(GraphQL::Schema) do
      namespace :source_order_blast
      query_fields { field(:greeting, :string).resolve { 'Mine!' } }
    end

    OtherBlastSource.build_query
    assert(schema.query_field?(:farewell))
    assert_raises(Rails::GraphQL::DuplicatedError) { execute('{ farewell }', schema: schema) }
  end

  def test_child_schema_inheriting_an_imported_source_field
    ChildSource.build_query
    parent = Class.new(GraphQL::Schema) do
      self.abstract = true
      import_into(:query, ChildSource)
    end
    child = Class.new(parent) { namespace :source_order_child }

    assert_result({ data: { greeting: 'Hello!' } }, '{ greeting }', schema: child)
  end

  def test_proxy_field_with_options_on_an_imported_field
    EarlySource.build_query

    assert_raises(Rails::GraphQL::DuplicatedError) do
      Class.new(GraphQL::Schema) do
        namespace :source_order_options
        import_into(:query, EarlySource)
        add_proxy_field(:query, EarlySource.query_field(:greeting), desc: 'Again')
      end
    end
  end

  def test_schema_import_of_a_late_source_is_not_duplicated
    ImportedSource.build_query
    schema = Class.new(GraphQL::Schema) do
      namespace :source_order_imported
      import_into(:query, ImportedSource)
    end

    assert_result({ data: { greeting: 'Hello!' } }, '{ greeting }', schema: schema)
  end

  def test_unregistered_source_does_not_attach_later
    GoneSource.build_query
    GoneSource.unregister!
    schema = Class.new(GraphQL::Schema) { namespace :source_order_gone }
    schema.register!

    refute(schema.query_field?(:greeting))
  end

  class ShipSource < GraphQL::ActiveRecordSource
    self.model = 'LiteShip'
    namespace :source_order_record
  end

  def test_record_source_built_before_its_schema
    ShipSource.build_object
    ShipSource.build_query
    schema = Class.new(GraphQL::Schema) { namespace :source_order_record }

    names = LiteShip.order(:id).pluck(:name).map { |name| { name: name } }
    assert_result({ data: { liteShips: names } }, '{ liteShips { name } }', schema: schema)
  end

  def test_source_built_before_its_schema
    LateSource.build_query
    schema = Class.new(GraphQL::Schema) { namespace :source_order_late }

    assert_result({ data: { greeting: 'Hello!' } }, '{ greeting }', schema: schema)
  end

  def test_source_built_after_its_schema
    EarlySource.build_query

    assert_result({ data: { greeting: 'Hello!' } }, '{ greeting }', schema: EarlySchema)
  end
end
