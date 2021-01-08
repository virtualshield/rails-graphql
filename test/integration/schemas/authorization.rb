class AuthorizationSchema < GraphQL::Schema
  namespace :authorization

  configure do |config|
    config.enable_string_collector = false
  end

  query_fields do
    field(:sample1, :string).resolve { 'Ok 1' }
    field(:sample2, :string).authorize.resolve { 'Ok 2' }
  end
end
