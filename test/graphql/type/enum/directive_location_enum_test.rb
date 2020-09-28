require 'config'

DESCRIBED_CLASS = Rails::GraphQL::Type::Enum::DirectiveLocationEnum

class DirectiveLocationEnumTest < GraphQL::TestCase
  def test_valid_input_int_is_datetime
    assert_equal(DESCRIBED_CLASS.valid_input?(1), false)
  end
end