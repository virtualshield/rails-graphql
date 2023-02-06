---
layout: default
title: Field Lists - Guides
description: All you can do when dealing with a list of fields
---

# Field Lists

Field lists are found in classes that contain a single list of fields ([Interfaces](/guides/interfaces),
[Inputs](/guides/inputs), [Objects](/guides/objects), and [Sets](/guides/alternatives#set-definition))
or multi-schema-based fields ([Schemas](/guides/schemas) and [Sources](/guides/sources)).

You can pretty much call the same methods in both scenarios, and the difference is that you need
to provide the type in the multi-schema-based ones. However, when using the block to focus
on one specific schema type, you can treat the block as if you were dealing with a single list
of fields.

```ruby
# Single list of fields
disable_fields(:field1, :field2)

# Multi-schema-based list of fields
disable_fields(:query, :field1, :field2)

# Using the block to interact with the multi-schema-based list of fields
query_fields do
  disable_fields(:field1, :field2)
end
```

{: .note }
> When the name is different between single and multi, they will be listed as `single` / `multi`.

## The List

### Accessing

`fields(initialize = nil)` /<br/> `fields_for(type, initialize = nil)`

Returns the list of fields. They all use
<a href="https://ruby-concurrency.github.io/concurrent-ruby/1.1.5/Concurrent/Map.html" target="_blank" rel="external nofollow">Concurrent::Map</a>
with the sanitized name as the keys and the fields as the values. The list is only
initialized when explicitly requested, otherwise, it will return `nil`.

```ruby
# Single form
fields                       # May return nil
fields(true)                 # Always returns a Concurrent::Map

# Multi form
fields_for(:query)           # May return nil
fields_for(:query, true)     # Always returns a Concurrent::Map
```

### Checking

`fields?` /<br/> `fields_for?(type)`

Check if the list of fields has been initialized and has items.

```ruby
# Single form
fields?

# Multi form
fields_for?(:query)
```

## Adding Fields

### Regular

`field(name, type, **settings, &configure_block)` /<br/> `add_field(type, name, type, **settings, &configure_block)`

Allows you to add a field to the list. Fields within a list needs to have a unique name.
If a field with the same name already exists, a [`DuplicatedError`](/handbook/exceptions#DuplicatedError) will be raised.

```ruby
# Single form
field(:name, :string)

# Multi form
add_field(:query, :name, :string)
```

Read more about [fields](/guides/fields).

### Safe

`safe_field(name, type, **settings, &configure_block)` /<br/> `safe_add_field(type, name, type, **settings, &configure_block)`

This works similarly to the above version, except that the exception is already rescued
for you. It's best used with [Sources](/guides/sources).

```ruby
# Single form
safe_field(:name, :string)

# Multi form
safe_add_field(:query, :name, :string)
```

### Proxy

`proxy_field(field, alias = nil, **settings, &configure_block)` /<br/> `add_proxy_field(type, field, alias = nil, **settings, &configure_block)`

Add a field that is a proxy to the other provided field. This not only checks for the
uniqueness of the name but also if the provided one is compatible with the list,
you can’t add a proxy to a mutation field on a query list, for example.

```ruby
# Single form
proxy_field(GraphQL::User[:name])

# You can give it a different name when adding the proxy
proxy_field(GraphQL::User[:name], :user_name)
# OR
proxy_field(GraphQL::User[:name], as: :user_name)
# OR
proxy_field(GraphQL::User[:name], alias: :user_name)

# Multi form
add_proxy_field(:query, GraphQL::User[:name])
```

**Proxy fields is an advanced feature.** Read more about [proxy fields](/guides/advanced/fields#proxies).

### Importing

#### From Class

`import(source)` /<br/> `import_into(type, source)`

Allows importing one or multiple fields from the given source into the list. Importing means
that all fields will be added as proxies of the source's fields. The source can be an Array,
a Hash-like with the fields on the values, another object with a list of fields,
a [Set Alternative](/guides/alternatives#set-definition), or
a [Standalone Alternative](/guides/alternatives#standalone-definition).

```ruby
# Single form
import(GraphQL::WithName)

# Multi form
import_into(:query, GraphQL::Queries::Users)
```

#### From Module

`import_all(module, recursive: false)` /<br/> `import_all_into(type, module, recursive: false)`

Allows importing several classes of fields from the given module into the list. This is a
powerful feature for organizing and sharing your code. For every constant found in the module,
call the above method if the constant is a class or call itself again if running recursively
and the constant is another module.

```ruby
# Single form
import_all(GraphQL::UserFields)

# Multi form
import_all_into(:query, GraphQL::Queries)
```

`NO EQUIVALENCY` /<br/> `import_all(module, recursive: false)`

The multi-schema-based list has a syntax sugar for importing a whole module where its name
already dictates what type is being imported.

```ruby
# Multi form
import_all(GraphQL::Queries)
```

## Changing Fields

### Simple

`change_field(name, **changes, &configure_block)` or<br/> `overwrite_field(name, **changes, &configure_block)`

You can use this to change several aspects of your your fields, which supports a block
to change even more aspects.

```ruby
# Single form
change_field(:name, null: true)

# With a block
change_field(:name, null: true) do
  argument(:first, :bool, null: false, default: true)
end

# Using the alias
overwrite_field(:name, null: true)

# Multi form
change_field(:query, :name, null: true)
```

### Block Only

`configure_field(name, &configure_block)`

This is a subset of the above, where the objective is to go straightforward to the block.
Use this method when the changes only involve adding arguments or directives.

```ruby
# Single form
configure_field(:name) do
  argument(:first, :bool, null: false, default: true)
end

# Multi form
configure_field(:query, :name) do
  argument(:first, :bool, null: false, default: true)
end
```

### Disable Fields

`disable_fields(name, *names)`

A quick shortcut to change the `enabled` status of one or more fields to `false`.

```ruby
# Single form
disable_fields(:field1, :field2)

# Multi form
disable_fields(:query, :field1, :field2)
```

### Enable Fields

`enable_fields(name, *names)`

A quick shortcut to change the `enabled` status of one or more fields to `true`.

```ruby
# Single form
enable_fields(:field1, :field2)

# Multi form
enable_fields(:query, :field1, :field2)
```

Read more about [changing fields](/guides/fields#changing-fields).

## Searching Fields

{: #checking-existence }
### Checking

`has_field?(by)`

Checks if the list has a field. It accepts the name as a symbol, the GQL name as a string,
or another field, as in checking a field with the same name.

```ruby
# Single form
has_field?(:first_name)
has_field?('firstName')

# Multi form
has_field?(:query, :first_name)
has_field?(:query, 'firstName')
```

### Finding

`find_field(by)` or `[by]`

Look for a field and return it. It accepts the name as a symbol, the GQL name as a string,
or another field, as in finding a field with the same name.

```ruby
# Single form
find_field(:first_name)
find_field('firstName')

# OR
self[:first_name]
self['firstName']

# Multi form
find_field(:query, :first_name)
find_field(:query, 'firstName')

# OR
self[:query, :first_name]
self[:query, 'firstName']
```

### Force Finding

`find_field!(by)`

Same as above, but it will raise a [`NotFoundError`](/handbook/exceptions#NotFoundError)
if the field was not found.

```ruby
# Single form
find_field!(:first_name)
find_field!('firstName')

# Multi form
find_field!(:query, :first_name)
find_field!(:query, 'firstName')
```

## Others

### All Field Names

`field_names(enabled_only = true)` /<br /> `field_names_for(type, enabled_only = true)`

Get a list of all the GQL names of the fields in the list. By default, it returns only enabled
fields. Passing a second argument as `false` will return from all fields.

```ruby
# Single form
field_names                       # => ['fieldOne']
field_names(false)                # => ['fieldOne', 'disabledFieldTwo']

# Multi form
field_names_for(:query)           # => ['fieldOne']
field_names_for(:query, false)    # => ['fieldOne', 'disabledFieldTwo']
```

Read more about [names](/guides/names).

### Enabled Fields

`enabled_fields` /<br /> `enabled_fields_from(type)`

Returns an iterable list of all the enabled fields. It uses an
<a href="https://ruby-doc.org/core-3.0.0/Enumerator/Lazy.html" target="_blank" rel="external nofollow">`Enumerator::Lazy`</a>
for performance purposes.

```ruby
# Single form
enabled_fields.each { |field| puts field.gql_name }

# Multi form
enabled_fields_from(:query).each { |field| puts field.gql_name }
```

### Attaching Directives

{: .warning }
> **Unavailable**
> This feature is yet to be published.

`attach(directive, to: , **arguments)` /<br /> `attach(directive, to: , fields: , **arguments)`

Allows attaching a directive, by instance or name plus arguments, to one or more fields.

```ruby
# Single form
attach(GraphQL::DeprecatedDirective(), to: %i[users user])

# Multi form
attach(GraphQL::DeprecatedDirective(), to: :query, fields: %i[users user])

# Using name and arguments
attach(:deprecated, reason: 'Just because.', to: %i[users user])
```

## Multi form Only

The multi-schema-based list provides a series of methods per type as syntax sugar to interact
with their specific list.

{: #accessing-multi }
### Accessing

`{type}_fields`

Access the list of fields of that type. It supports a block to interact exclusively with that list.
Different from [the regular access](#accessing), this alone will never initialize the list.

```ruby
# Accessing
query_fields
mutation_fields
subscription_fields

# Interacting
query_fields {  }
mutation_fields {  }
subscription_fields {  }
```

{: #checking-multi }
### Checking

`{type}_fields?`

Check if the list of that type has been initialized and has items.

```ruby
query_fields?
mutation_fields?
subscription_fields?
```

{: #adding-fields-multi }
### Adding Fields

`add_{type}_field(name, type, **settings, &configure_block)`

Works as a shortcut for the [regular](#regular) form of adding fields.

```ruby
add_query_field(:name, :string)
add_mutation_field(:name, :string)
add_subscription_field(:name, :string)
```

{: #checking-existence-multi }
### Checking for a Field

`{type}_field?(by)`

Works as a shortcut for the [`has_field?`](#checking-existence).

```ruby
query_field?(:name)
mutation_field?(:name)
subscription_field?(:name)
```

{: #finding-multi }
### Finding a Field

`{type}_field(by)`

Works as a shortcut for the [`find_field`](#checking-existence).

```ruby
query_field(:name)
mutation_field(:name)
subscription_field(:name)
```

### The Type Name

`{type}_type_name`

Returns the name of the Type of the list as it is exposed to GraphQL schema.

```ruby
query_type_name            # _Query
mutation_type_name         # _Mutation
subscription_type_name     # _Subscription
```

### Type Object

`{type}_type`

It returns an
<a href="https://ruby-doc.org/stdlib-3.0.0/libdoc/ostruct/rdoc/OpenStruct.html" target="_blank" rel="external nofollow">`OpenStruct`</a>
that acts like a fake [Object](/guides/objects) for that type. The fake type is only returned
if there are fields added to that list.

```ruby
# app/graphql/app_schema.rb
query_type

# Returns
OpenStruct.new(
  name: "GraphQL::AppSchema[:query]",
  kind: :object,
  object?: true,
  kind_enum: 'OBJECT',
  fields: @query_fields,
  gql_name: '_Query',
  description: nil,
  interfaces?: false,
  internal?: false,
).freeze
```
