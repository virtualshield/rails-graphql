require 'config'

class StringScalarTest < GraphQL::TestCase
  test '#as_json' do
    x = Rails::GraphQL::Type::Scalar::StringScalar.as_json
    assert x == "1"
  end
end
