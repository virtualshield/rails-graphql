### Description

Allows documenting {{ include.type }}s. This value can be retrieved using [introspection](/guides/introspection)
or during a [to_gql](/guides/customizing/controller#describe) output. Within the class, `desc`
works as a syntax sugar for `self.description = ''`. It also supports descriptions from
[I18n](/guides/i18n).

```ruby
# app/graphql/{{ include.type }}s/{% if include.file %}{{ include.file }}{% else %}{{ include.name | downcase }}{% endif %}.rb
module GraphQL
  class {{ include.name }} < GraphQL::{{ include.type | capitalize }}
    desc 'This is awesome!'
  end
end
```
