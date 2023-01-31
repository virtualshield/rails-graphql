---
layout: default
title: Global ID - Guides
description: The customized support of Global ID for GraphQL elements
---

# Global ID

{: .note }
> **Important**
> This is the beginning of a much larger implementation, where pretty much anything would be
> able to be stored as simple Global IDs.

This gem implements its own version of Rails
<a href="https://github.com/rails/globalid" target="_blank" rel="external nofollow">Global ID</a>.
The purpose is to identify GraphQL components within your application uniquely. This feature
is widely by [request caching](/guides/advanced/requests#caching) and
[request compiling](/guides/advanced/requests#compiling).

## How it Looks Like

```ruby
"gql://base/Type/String"
"gql://base/Schema/query/welcome"
"gql://base/Directive/deprecated"
"gql://base/Directive/deprecated?reason=Just+because"
```

## The Components

The URI is can be composed of:

`schema`
: It will always be `gql`

`namespace`
: Based on the primary namespace of the component, in
<a href="https://edgeapi.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-dasherize" target="_blank" rel="external nofollow">dash</a> format

`class_name`
: The top-most class responsible for the component

`scope?`
: For schema fields only, either `query`, `mutation`, or `subscription`

`name`
: The symbolized name of the object

`params?`
: A URI-compatible list of parameters

## How to Use

You can get the GID of any element by calling `.to_global_id.to_s` or simply `.to_gid.to_s`.
Then, you can call `GraphQL::GlobalID.find` to get the element of a global id.

{: .rails-console }
```ruby
:001 > GraphQL::AppSchema[:query][:welcome].to_gid.to_s
    => "gql://base/Schema/query/welcome"
:002 > GraphQL::GlobalID.find("gql://base/Schema/query/welcome")
    => #<Rails::GraphQL::Field::OutputField
       #  GraphQL::AppSchema[:query]
       #  welcome: String!>
```
