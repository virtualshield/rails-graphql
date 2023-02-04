---
layout: default
title: Generators - Guides
description: All the available generators available to use and their arguments
---

# Generators

Here you will find all the available generators to facilitate the creation of
your application’s GraphQL features.

{: .important }
> **Important**
> More generators will be delivered for version 1.0.0

## graphql:install

Add an initializer with some [settings](/handbook/settings), creates a new schema using
[`graphql:schema`](#graphqlschema), add folders and `.keep` files with the structure
of the `graphql` folder, and add some basic routes.

Arguments
: <span></span>

schema
: The name of the schema
: Default: Your application's name

directory
: Where to put the file
: Default: `app/graphql`

skip_keeps
: Marks if it should not add the `.keep` files and respective folders
: Default: `false`

skip_routes
: Marks if it should not add any routes
: Default: `false`

**Example:**

```bash
$ rails g graphql:install
```

{: .directory }
```
/ app
  / graphql
    / directives
    / enums
    / fields
    / inputs
    / interfaces
    / mutations
    / object
    / queries
    / scalars
    / sources
    / subscriptions
    / unions
    - app_schema.rb
/ config
  / initializers
    - graphql.rb
  - routes.rb
```

```ruby
# config/routes.rb
get  "/graphql/describe", to: "graphql/base#describe"
get  "/graphiql",         to: "graphql/base#graphiql"
post "/graphql",          to: "graphql/base#execute"
```

## graphql:schema

Add a new GraphQL schema inside the `graphql` folder.

Arguments
: <span></span>

name
: The name of the schema
: Default: Your application's name

directory
: Where to put the file
: Default: `app/graphql`

**Example:**

```bash
$ rails g graphql:schema SampleSchema
```

```ruby
# app/graphql/sample_schema.rb
module GraphQL
  class SampleSchema < GraphQL::Schema
  end
end
```

Read more about [schemas](/guides/schemas).

## graphql:controller

Add a new controller to your application and add the `GraphQL::Controller` concern into it.

Arguments
: <span></span>

name
: The name of the controller
: Default: `GraphQLController`

**Example:**

```bash
$ rails g graphql:controller SampleController
```

```ruby
# app/controllers/sample_controller.rb
class SampleController < ApplicationController
  include GraphQL::Controller
end
```

Read more about [customizing the Controller](/guides/customizing/controller).

## graphql:channel

Add a new Action Cable channel to your application and add the `GraphQL::Channel` concern into it.

Arguments
: <span></span>

name
: The name of the channel
: Default: `GraphQLChannel`

**Example:**

```bash
$ rails g graphql:channel SampleChannel
```

```ruby
# app/channels/sample_channel.rb
class SampleChannel < ApplicationCable::Channel
  include GraphQL::Channel
end
```

Read more about [customizing the Channel](/guides/customizing/channel).
