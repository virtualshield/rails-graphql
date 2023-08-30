---
layout: default
steps: true
toc: false
title: Getting Started
description: The basics about this gem and what you will find
---

## Installation

{% include installation.md %}

## Using Generators

The easiest way to start is by using the [generators provided](/guides/generators).

```bash
# This will create a schema where your objects will be added
$ rails g graphql:schema
# This will create a controller to receive and process the requests
$ rails g graphql:controller
```

## Directory Structure

All your application's GraphQL schema files should live inside `app/graphql`.
However, `Rails::GraphQL` will coordinate with `Rails` the expected classes and
modules inside of it, which differs slightly from regular Rails app folders.
Think of it as GraphQL's own app folder.

{: .directory }
```
/ app
  / controllers
    - graphql_controller.rb
  / graphql # Consider it the root of your GraphQL app
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
  / models
```

{: .highlight }
> This is fully compatible with
> <a href="https://github.com/fxn/zeitwerk" target="_blank" rel="external nofollow">Zeitwerk</a>.

Those directories won't be created automatically. Use this as a reference.
The ones listed here have special meanings.

Read more about the [directory structure](/guides/architecture#directory-structure).

## Setup your Schema

Once you generate a schema, you can add fields and many other things.
Let's set up a very simple field that will return this unique output.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    query_fields do
      field(:welcome, :string, null: false)
    end

    def welcome
      'Hello World!'
    end
  end
end
```

Now you can try it out on your Rails console.

{: .rails-console }
```ruby
:001 > GraphQL::AppSchema.execute('{ welcome }')
    => {"data"=>{"welcome"=>"Hello World!"}}
```

This is the minimum required to have a very basic setup.

Read more about [schemas](/guides/schemas).

## Using a Controller

If you have generated a controller, you may notice that it only has a module
added to it. All the necessary functionality is already provided by default.
The only thing added for this example is the skip of the authenticity token since
we will be using a `POST` method.

```ruby
# app/controllers/graphql_controller.rb
class GraphQLController < ApplicationController
  include GraphQL::Controller

  # Added manually
  skip_before_action :verify_authenticity_token
end
```

Let’s set it up properly by adding a route and running a test.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  post '/graphql', to: 'graphql#execute'
end
```

Now, once you have your server running, you can try requesting the result from
your application. For the sake of demonstration only, here is a `CURL` example.

```bash
$ curl -d '{"query":"{ welcome }"}' \
       -H "Content-Type: application/json" \
       -X POST http://localhost:3000/graphql
# {"data":{"welcome":"Hello World!"}}
```

Read more about [customizing the Controller](/guides/customizing/controller).
