---
layout: default
title: Queries - Guides
description: The GraphQL operation responsible for fetching data from your API
---

# Query Operations

```graphql
query { welcome }
```

Query is one of the three operations that you can run on GraphQL. Queries' purpose
is to perform a read-only fetch of data from the server, and they are handled
by [requests](/guides/request).

## Definition

Queries can be composed of 5 different elements:

`[type]`
: `query` - Optional for single-query documents

`[name]`
: An optional name

`[variables]`
: An optional set of [variables](/guides/request#variables)

`[directives]`
: An optional set of [directives](/guides/directives)

`selection`
: One or more fields from the<br/>schema [query fields](/guides/schemas#fields)

```graphql
# type     name      variables    directives  selection
  query FirstQuery($var: String!) @directive { welcome }
```

If your request only involves one query that does not have a name, variables,
or directives, you can skip the type and write the selection straightaway.

```graphql
{ welcome }
```

## Fields

The top-level fields in the selection of your queries are called `entry points`,
and they must exist in the [query fields](/guides/schemas#fields) of your schema.
From there, depending on the returning type of each field, you can further specify
what fields you want. You don't have to worry if the field returns an array.

```graphql
{
  allUsers       # entry point GraphQL::AppSchema[:query][:all_users]
  {              # an array of GraphQL::User < GraphQL::Object
    id           # GraphQL::User[:id]
    name         # GraphQL::User[:name]
  }
  me             # another entry point GraphQL::AppSchema[:query][:me]
  {              # one GraphQL::User < GraphQL::Object
    id           # GraphQL::User[:id]
    name         # GraphQL::User[:name]
  }
}
```

Here is an example of a response from the above:

```json
{
  "data": {
    "allUsers": [
      { "id": 1, "name": "John Doe" },
      { "id": 2, "name": "Jane Doe" }
    ],
    "me": { "id": 1, "name": "John Doe" }
  }
}
```

You will always get exactly what you requested, in the exact same order (in case of repeated
fields, only the first will be added).

{: .note }
> **Note**
> You will notice that commas are not really necessary in your documents.
> However, you can still use them.

Read more about [fields resolution](/guides/request#resolving).

### Typename

At any given point of your selection, you may request a special field named `__typename`. Its
sole purpose is to return the name of the type of the object of the current scope. For example:

```graphql
{
  __typename
  me { __typename id }
}
```

```json
{
  "data": {
    "__typename": "_Query",
    "me": { "__typename": "User", "id": 1 }
  }
}
```

This can be really valuable when your front end works with
<a href="https://www.typescriptlang.org/" target="_blank" rel="external nofollow">TypeScript</a>
or when dealing with
[interfaces](/guides/interfaces) and [unions](/guides/unions) (the result will be the actual type,
not the interface or the union names).

## Fragments

Fragments are a great feature to simplify your queries. The idea is to put a similar selection
of fields in a single place and then reuse it throughout your request document. The above
example could be re-written using a fragment as:

```graphql
query {
  allUsers { ...UserFields }
  me { ...UserFields }
}

fragment UserFields on User { id name }
```

Read more about [fragments](/guides/fragments).
