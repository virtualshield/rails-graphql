require 'config'

class GraphQL_GraphiQLTemplateTest < GraphQL::TestCase
  TEMPLATE_PATH = Pathname.new(__dir__).join('../../lib/rails/graphql/railties/app/views/graphiql.html.erb')

  def test_uses_versioned_graphiql_assets
    content = TEMPLATE_PATH.read

    assert_includes(content, 'https://cdn.jsdelivr.net/npm/graphiql@1.8.2/graphiql.min.css')
    assert_includes(content, 'https://cdn.jsdelivr.net/npm/graphiql@1.8.2/graphiql.min.js')
  end

  def test_does_not_use_unversioned_unpkg_graphiql_assets
    content = TEMPLATE_PATH.read

    refute_includes(content, '//unpkg.com/graphiql/graphiql.min.css')
    refute_includes(content, '//unpkg.com/graphiql/graphiql.min.js')
  end
end
