---
layout: default
title: Mutations - Guides
description: The GraphQL operation responsible for changing and fetching data from your API
---

# Mutation Operations

```graphql
mutation { createUser }
```

Mutation is one of the three operations that you can run on GraphQL. Mutations' purpose
is to perform changes to the data in the server and then fetch data based on the changes.
Mutations are handled by [requests](/guides/request).

## Definition

Mutations can be composed of 5 different elements:

`type`
: `mutation`

`[name]`
: An optional name

`[variables]`
: An optional set of [variables](/guides/request#variables)

`[directives]`
: An optional set of [directives](/guides/directives)

`selection`
: One or more fields from the<br/>schema [query fields](/guides/schemas#fields)

```graphql
#   type         name      variables    directives  selection
  mutation FirstMutation($var: String!) @directive { welcome }
```

## Fields

The top-level fields in the selection of your mutations are called `entry points`,
and they must exist in the [mutation fields](/guides/schemas#fields) of your schema.
Mutations work similarly to [queries](/guides/queries), but the entry points
should change the data before it can be fetched and formatted.

```graphql
mutation {
  createUser     # entry point GraphQL::AppSchema[:mutation][:create_user]
  {              # one GraphQL::User < GraphQL::Object with the new record
    id           # GraphQL::User[:id]
    name         # GraphQL::User[:name]
  }
}
```

Here is an example of a response from the above:

```json
{ "data": { "createUser": { "id": 3, "name": "Jazz Doe" } } }
```

Read more about [performing fields](/guides/request#performing).

### Extra Definitions

Mutation [fields](/guides/fields) accept some additional settings when they are being defined.

#### `call`

You can add this named argument to your field's definition to indicate which method it should
use when performing the mutation. By default, the called method is the `bang!` version of the
field's name.

```ruby
# app/graphql/app_schema.rb
field(:create_user, 'User')                      # Calls create_user!
field(:create_user, 'User', call: :add_user)     # Calls add_user
```

#### `perform`

You can manually set a [callback](/guides/events#callbacks) as the `perform` step. This can
be done using the [chaining definition](/guides/fields#chaining-definition) or inside the
block definition.

```ruby
# app/graphql/app_schema.rb
field(:create_user, 'User').perform { User.create! }
# OR
field(:create_user, 'User') do
  perform { User.create! }
end
```
