---
layout: default
title: Enums - Guides
description: The second leaf type in GraphQL
---

# Enums

```graphql
enum Role {
  ADMIN
  SUPPORT
}
```

Enums are the second leaf type in GraphQL. They work similarly to [string scalars](/guides/scalars#string),
but only a pre-determined list of values is accepted.

## Creating an Enum

You can define enums on a file or using the shortcut on the schema.

```ruby
# app/graphql/enums/role.rb
module GraphQL
  class Role < GraphQL::Enum
    add 'ADMIN'
    add 'SUPPORT'
  end
end

# OR

# app/graphql/app_schema.rb
enum 'Role' do
  add 'ADMIN'
  add 'SUPPORT'
end

# OR even
enum 'Role', values: %i[admin support]
```

Enums follow the same pattern as scalars. Therefore, the same rules applied to
[creating your own scalar](/guides/scalars#creating-your-own-scalar) apply to enums.
However, it's unlikely that you will need to rewrite such methods in your enums.

{% include type-description.md type="enum" name="Role" %}

### Values

You can add values to any enum by calling `add`. Values must be unique,
considering they will always be strings in capital letters. You can also provide
individual description and directives for each value.

```ruby
# These are all the same, since values are always converted
add :admin
add 'admin'
add 'ADMIN'

# You can add description to the values
add 'ADMIN', desc: 'Has superpowers'
add 'ADMIN', description: 'Has superpowers'

# You can also add directives
add 'ADMIN', directives: GraphQL::DeprecatedDirective.new
```

Similar to [fields](/guides/fields#directives), enum values have a shortcut for
assigning a deprecated directive:

```ruby
add 'SUPPORT', deprecated: 'Just because'
```

### Index-based Enums

The GraphQL spec stipulates that enums "are not references for a numeric value". However,
to facilitate the translation between numeric-based enums that you might have in your application,
this gem provides the `indexed!` method to mark that numeric values that are about to be added
to the response should be translated accordingly.

```ruby
# app/graphql/enums/role.rb
add 'ADMIN'
add 'SUPPORT'

as_json(0)           # "0"
valid_output?(0)     # false

indexed!

as_json(0)           # "ADMIN"
valid_output?(0)     # true
```

{% include type-creators.md type="enum" %}

## Using Enums

Once they are defined, you can set them as the type of any field, output or input.
You will always get the capitalized string version of enums for output fields.
For inputs, you always have to provide capitalized strings,
even if the enum is marked as [`indexed!`](#index-based-enums).

```ruby
object 'User' do
  field :id
  field :name
  field :role, 'Role'
end

field(:create_user, 'User', null: false) do
  argument :name, :string, null: false
  argument :role, 'Role', null: false
end
```

```graphql
mutation {
  createUser(user: { name: "John Doe", role: "ADMIN" }) { id name role }
}
```

```json
{
  "data": {
    "createUser": {
      "id": "1",
      "name": "John Doe",
      "role": "ADMIN",
    }
  }
}
```

### The instance

When an enum is received as an input, you will get an instance of that enum's class as
the received value. You can do a couple of things with that instance to facilitate your life.
Here is the list, with examples based on the last example:

`to_s`
: Returns the plain string value<br/>`"ADMIN"`

`to_sym`
: Returns a symbol in lowercase<br/>`:admin`

`to_i`
: Returns the index, for indexed enums or not<br/>`0`

`deprecated?`
: Checks if the received value is deprecated<br/>`false`

`deprecated_reason`
: Returns the deprecation reason, if any<br/>`nil`
