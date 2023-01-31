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

## graphql:schema

Add a new GraphQL schema inside the `graphql` folder.

**Arguments:**

name
: The name of the schema
: Default: Your application's name

**Example:**

```bash
$ rails g graphql:schema Sample
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

Add a new controller to your application and add the `GraphQL::Controller` concern into ir.

**Arguments:**

name
: The name of the controller
: Default: `GraphQL`

**Example:**

```bash
$ rails g graphql:controller Sample
```

```ruby
# app/controllers/sample_controller.rb
class SampleController < ApplicationController
  include GraphQL::Controller
end
```

Read more about [customizing the Controller](/guides/customizing/controller).
