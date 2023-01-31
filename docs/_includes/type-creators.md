### For gem Creators

Once you have created your {{ include.type }}s in your gem, remember to add them into
[`config.known_dependencies`](/handbook/settings#known_dependencies).
It is not recommended to `require` such files in your gem.

```ruby
Rails::GraphQL.config.known_dependencies[:{{ include.type }}].update(
  my_gem_{{ include.type }}: "#{__dir__}/{{ include.type }}s/my_gem_{{ include.type }}",
)
```
