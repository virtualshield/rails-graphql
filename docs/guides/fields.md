---
layout: default
title: Fields - Guides
description: All you need to know about how to work with all types of fields
---

# Fields

Fields are how you can navigate through a GraphQL schema and get precisely
the data you want for your front end. You will find fields in all sorts of
flavors and places, and this area will guide you through the
basics and intermediate of them.

## Basic Concepts

```ruby
field :name, :string
```

A field will always be composed of a `name`, a `type`, and a sequence of settings
provided through named arguments.

The only thing required is the name, preferably as a symbol in snake case.

By default, the type will be `:string`, unless the field's name is `:id`,
which automatically makes it of the `:id` type.

```ruby
field :name
# Is the same as
field :name, :string

# AND

field :id
# Is the same as
field :id, :id
```

It’s always recommended to provide a type, even when it is `:id, :id`, for clarity.

The type represents what the field will deliver when it is an output field
or what it accepts when it is an input field.

Fields can also be configured using a block, but just for some options:

```ruby
field(:name, :string) do
  desc 'The name of the thing'
  # ...
end
```

{: .no_toc }
### Additional Options

{: .no_toc }
#### `desc:`/`description:` `String` = `nil`

Allows documenting the field. This value can be retrieved using [introspection](/guides/introspection)
or during a [to_gql](/guides/customizing/controller#describe) output. Within the block, `desc`
works as a syntax sugar for `self.description = ''`.

{: .no_toc }
#### `null:` `Boolean` = `true`

Marks if the field accepts or can deliver a null value.

{: .no_toc }
#### `array:` `Boolean` = `false`

Marks if the field accepts or can deliver an array of values.

{: .important }
> As of now, fields only support one-dimensional arrays.

{: .no_toc }
#### `nullable:` `Boolean` = `true`

Marks if the array may contain null values.

{: .no_toc }
#### `full:` `Boolean` = `false`

A shortcut to `null: false, array: true, nullable: false`.

{: .no_toc }
#### `enabled:` `Boolean` = `nil`

Marks if the field is available to be used.

{: .no_toc }
#### `disabled:` `Boolean` = `false`

Marks if the field is unavailable to be used.

{: .no_toc }
#### `directives:` `Directive`/`[Directive]` = `nil`

One or more directives to attach to the field. Within the block, use the `use` method.

## Input Fields

Input fields will be present in Input-type objects. Those fields will help in the
process of translating external values into Ruby values.

```ruby
# app/graphql/inputs/user_input.rb
class GraphQL::UserInput < GraphQL::Input
  field :name, :string, null: false,
    desc: 'The name of the user'
end
```

Read more about the [Inputs](/guides/inputs).

{: .no_toc }
### Additional Options

{: .no_toc }
#### `default:` `Object` = `nil`

Sets the default value of the field.
The field will use its default value if no external value is provided.
**Beware**, the default value will also be used when the provided external value is `nil`.

## Output Fields

Output fields will be present in several places, like [Objects](/guides/objects),
[Interfaces](/guides/interfaces), [Schemas](/guides/schemas), and [Sources](/guides/sources),
to name a few.

Their purpose is to either give you a plain value (leaf) or access to
types that have nested fields (branch).

```ruby
# app/graphql/objects/user.rb
class GraphQL::User < GraphQL::Object
  # Leaf field
  field :name, :string, null: false,
    desc: 'The name of the user'
end

# app/graphql/app_schema.rb
query_fields do
  # Branch field
  field :me, 'User', null: false,
    desc: 'Get information about the current user'
end
```

{: .no_toc }
### Additional Options

{: .no_toc }
#### `arguments:` `Argument`/`[Argument]` = `nil`

One or more arguments to be added to the field. Within the block, use the `argument` method.

{: .no_toc }
#### `method_name:` `Symbol` = `nil`

The name of the method used to fetch the field's data when [resolving](#resolving) the field.

{: .no_toc }
#### `deprecated:` `Boolean`/`String` = `nil`

Marks the field as [deprecated](/guides/directives#deprecated) when provided with a truthy value.
Additionally, you can pass a `String` to set the reason for the deprecation.

{: .no_toc }
#### `broadcastable:` `Boolean` = `nil`

Marks if the field is broadcastable or not, which is only relevant when working with
[broadcasting](/guides/subscriptions#broadcasting) subscriptions.

### Arguments

All output fields accept additional arguments.
This list of unique arguments allows for exchanging expected behaviors that the request
has about this field. Arguments accept both leaf values or [Inputs](/guides/inputs).

You have some options while adding your arguments:

```ruby
# Any of these options, that produces the same result,
# are good for a short list of arguments (1 - 2)
field :name, :string,
  arguments: argument(:first, :bool) + argument(:last, :bool)
field :name, :string,
  arguments: argument(:first, :bool) & argument(:last, :bool)
field :name, :string,
  arguments: [argument(:first, :bool), argument(:last, :bool)]

# In this scope, you can also shorten the line by using `arg` instead
field :name, :string, arguments: arg(:first, :bool) + arg(:last, :bool)

# For a more extensive list of arguments,
# use the block of the definition of the field
field(:name, :string) do
  argument :first, :bool, default: true
  argument :last, :bool, default: true
  argument :mid, :bool

  # This scope does not support the `arg` alias
end

# You can also use a syntax sugar
field :user, 'User', arguments: id_argument
# Which is equivalent to
field :user, 'User', arguments: argument(:id, :id, null: false)
# You can customize the name of the argument and all the other options as well
id_argument(:pid, null: true, desc: 'ID')
# Which is equivalent to
argument(:pid, :id, null: true, desc: 'ID')
```

Read more about the [Arguments](/guides/arguments).

### Resolving Fields

Resolving fields is the process of putting the data into the response during a request.
There are several ways a field can be resolved. For now, the important thing to know is
the meaning of the `:method_name` option. It tells where the data will come from.
When not defined, the request assumes it is the same as the field's name.

{: .note }
> [Standalone-defined fields](/guides/alternatives#standalone-definition) fallback to `:resolve`

Read more about the [Requests](/guides/requests).

### Mutation Fields

Mutations fields are a special type of output field that only exists in schemas, in the
`mutation_fields` list more precisely. Their purpose is to inform the request that one
extra step needs to happen before the field can actually be resolved. This step, called
`perform`, will make changes in the data under GraphQL.

```ruby
# app/graphql/app_schema.rb
mutation_fields do
  field :update_user, 'User', null: false,
    desc: 'Change the information about the current user'
end
```

Read more about the [Mutations](/guides/mutations).

### Subscription Fields

Subscription Fields are another special type of output field that only exists in, in the
`subscription_fields` list more precisely. Their purpose is to return values and
sign the request for updates that may happen with the data it first returned.

```ruby
# app/graphql/app_schema.rb
subscription_fields do
  field :me, 'User',
    desc: 'Get notified whenever the current user has been updated'
end
```

Read more about the [Subscriptions](/guides/subscriptions).

### Authorized Fields

All output fields support an authorization step. This step will attempt to check if the
request and its context provide enough scope to resolve the field.

Read more about the [Authorization](/guides/advanced/authorization).

### Events

Output fields support a series of events. Those events happens during the process of a request.
Special types of output fields may also have special types of events. Here is how you can
listen to events:

```ruby
field(:name, :string) do
  on(:prepare) { |event| puts event.inspect }
end
```

Read more about the [Events](/guides/events).

## Directives

All fields support directives. [Directives](/guides/directives) are an advanced feature
of GraphQL and this gem. Just as a reference, here is how you can add directives to
fields:

```ruby
field :name, :string, directives: GraphQL::DeprecatedDirective.new
# It also supports concatenating with + or &. These are all equivalent
field :name, :string,
  directives: GraphQL::ADirective.new + GraphQL::BDirective.new
field :name, :string,
  directives: GraphQL::ADirective.new & GraphQL::BDirective.new
field :name, :string,
  directives: [GraphQL::ADirective.new, GraphQL::BDirective.new]


# OR the block approach
field(:name, :string) do
  # These are the same thing
  use :deprecated, reason: 'Just because'
  use GraphQL::DeprecatedDirective(reason: 'Just because')
  use GraphQL::DeprecatedDirective.new(reason: 'Just because')
end

# Shortcut for deprecated directive
field(:name, :string, deprecated: 'Just because')
```

Read more about the [Directives](/guides/directives).

## Chaining Definition

You may have noticed that in some examples, a chaining approach was used to configure a field.
This is widely available for the methods you would likely call within the block.

```ruby
field(:name, :string)
  .argument(:first, :bool)
  .argument(:last, :bool)
  .use(:deprecated, reason: 'Just because')
  .on(:prepare) { |event| puts event.inspect }
  .resolve { 'The name!' }
```

However, the recommendation is to use just in the simple situations.

Read more about the [Recommendations](/guides/recommendations).

## I18n Support

If your GraphQL API is served as a public API, it may be interesting to
publish the documentation in several languages. Although you can't change the
name of the fields, the description can be defined in your YAML files.

```ruby
# app/graphql/app_schema.rb
query_fields do
  field :user, 'User'
end
```

```yaml
# config/locales/en.yml
en:
  graphql:
    field:
      user: Information about the current user
```

```graphql
type _Query {
  # Information about the current user
  user: User!
}
```

{: .warning }
> **Affects Performance**
> This is a heavy process, so it is recommended to enable only when delivering
> the documentation of your API or in development mode.

This feature is coordinated by [`config.enable_i18n_descriptions`](/handbook/settings#enable_i18n_descriptions)
and [`config.i18n_scopes`](/handbook/settings#i18n_scopes).

Read more about the [I18n](/guides/i18n).

## Changing Fields

Field definitions are not final. At any given point, you can change some of its behaviors.
However, changing it anywhere will affect the GraphQL application entirely.

This is useful when controlling the enabled/disabled state of fields and [proxy fields](/guides/advanced/fields#proxies).

```ruby
# app/graphql/interfaces/animal.rb
class GraphQL::Animal < GraphQL::Interface
  field :name, :string, desc: 'The name of the animal'
end

# app/graphql/objects/cat.rb
class GraphQL::Cat < GraphQL::Object
  # Fields are imported as proxies
  implements 'Animal'

  # Changes only the local version of the field
  change_field :name, desc: 'The name of the cat'
end

# app/graphql/objects/dog.rb
class GraphQL::Dog < GraphQL::Object
  # Fields are imported as proxies
  implements 'Animal'

  # A block allows changing other things
  change_field(:name, desc: 'The name of the dog') do
    argument(:nickname, :bool, null: false, default: false)
  end
end
```

You are allowed to change the `null`, `nullable`, `disabled`, `enabled`, `description`,
`default`, and `method_name` values, as well as increment the `arguments` and `directives`
within a block.

Proxy fields is an advanced feature. Read more about the [Proxy Fields](/guides/advanced/fields#proxies).

## Additional Notes

All fields have 6 indicators of exactly what they are:

`leaf_type?`
: Is it associated with a leaf type?

`input_type?`
: Is it being used as an input of data?

`output_type?`
: Is it being used as an output of data?

`mutation?`
: Does it have mutation capabilities?

`subscription?`
: Does it have subscription capabilities?

`proxy?`
: Is it a proxy of another field?

This is the tree of field classes and what modules they implement.

```
Object
↳ Rails::GraphQL::Field
  ↳ InputField
      + TypedField
  ↳ OutputField
      + AuthorizedField
      + ResolvedField
      + TypedField
    ↳ MutationField
    ↳ SubscriptionField
```
{% include hierarchy-sub.md %}
