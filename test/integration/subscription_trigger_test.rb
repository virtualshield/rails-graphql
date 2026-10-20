require 'integration/config'
require 'integration/schemas/sqlite'

SQLiteRecord.connection.create_table('lite_settings', force: :cascade) do |t|
  t.string 'key'
  t.integer 'user_id'
  t.boolean 'flag'
end

class LiteSetting < SQLiteRecord
end

class Integration_SubscriptionTriggerTest < GraphQL::IntegrationTestCase
  class SCHEMA < GraphQL::Schema
    namespace :subscription_trigger

    subscription_fields do
      field(:thing, :string, arguments: [arg(:user_id, :int), arg(:flag, :boolean)])
      field(:sized, :string, arguments: [arg(:size, :int, null: false), arg(:shift, :int, null: false)])
    end
  end

  class HashLike
    def initialize(values)
      @values = values
    end

    def [](key)
      @values[key]
    end

    def key?(key)
      @values.key?(key)
    end

    def each_pair(&block)
      @values.each_pair(&block)
    end
  end

  def test_trigger_for_reads_the_values_of_a_hash_like_object
    assert_equal([
      { user_id: 5, flag: false },
      { user_id: 5, flag: nil },
      { user_id: nil, flag: false },
      { user_id: nil, flag: nil },
    ], triggered_args(HashLike.new({ 'user_id' => 5, flag: false })))

    assert_equal([{ user_id: nil, flag: nil }], triggered_args(HashLike.new({ user_id: nil })))
  end

  def test_trigger_for_reads_the_values_of_each_hash_in_a_list
    assert_equal([
      { user_id: 5, flag: true },
      { user_id: 5, flag: nil },
      { user_id: nil, flag: true },
      { user_id: nil, flag: nil },
    ], triggered_args([{ 'user_id' => 5, 'flag' => true }]))
  end

  def test_trigger_for_reads_a_hash_as_one_object
    assert_equal([
      { user_id: 5, flag: false },
      { user_id: 5, flag: nil },
      { user_id: nil, flag: false },
      { user_id: nil, flag: nil },
    ], triggered_args({ 'user_id' => 5, flag: false }))
  end

  def test_trigger_for_reads_a_hash_key_named_as_a_hash_method
    object = { size: 5, 'shift' => 1 }
    assert_equal([{ size: 5, shift: 1 }], triggered_args(object, :sized))
    assert_equal({ size: 5, 'shift' => 1 }, object)

    assert_equal([], triggered_args({ size: 5 }, :sized))
    assert_equal([], triggered_args(HashLike.new({ size: 5 }), :sized))
  end

  def test_trigger_for_reads_the_attributes_of_a_record_with_a_key_column
    record = LiteSetting.new(key: 'k', user_id: 5, flag: false)
    expected = [
      { user_id: 5, flag: false },
      { user_id: 5, flag: nil },
      { user_id: nil, flag: false },
      { user_id: nil, flag: nil },
    ]

    assert_equal(expected, triggered_args(record))
    assert_equal(expected, triggered_args([record]))
  end

  def test_trigger_for_reads_nothing_from_an_object_without_keys
    object = Class.new { def [](*); raise 'not reached'; end }.new
    assert_equal([{ user_id: nil, flag: nil }], triggered_args(object))
  end

  def test_trigger_for_reads_the_methods_of_an_object
    object = Struct.new(:user_id, :flag).new(5, false)
    assert_equal([
      { user_id: 5, flag: false },
      { user_id: 5, flag: nil },
      { user_id: nil, flag: false },
      { user_id: nil, flag: nil },
    ], triggered_args(object))

    assert_equal([
      { user_id: 5, flag: false },
      { user_id: 5, flag: nil },
      { user_id: nil, flag: false },
      { user_id: nil, flag: nil },
    ], triggered_args([object]))
  end

  private

    def triggered_args(object, field = :thing)
      captured = nil
      provider = double(search_and_update: ->(**xargs) { captured = xargs })

      SCHEMA.stub(:subscription_provider, provider) do
        SCHEMA.subscription_field(field).trigger_for(object, and_prepare: false)
      end

      captured[:args]
    end
end
