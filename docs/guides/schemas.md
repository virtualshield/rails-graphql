---
layout: default
title: Schemas - Guides
description: Setting up a schema, its dependencies, and capabilities
---

# Schemas

```graphql
schema {
  query: _Query
  mutation: _Mutation
  subscription: _Subscription
}
```

Schema is the place where you will coordinate what features are available. The features
of a schema are divided into configuring, fields, dependencies,
subscriptions, cache, error handling, inline types, and type map interaction.

## Configuring

Some of the [settings](/handbook/settings) can be configured at a per schema level.
The application can have one value set globally, and the schema can have its own.

Here is the list of such settings:

* [`cache`](/handbook/settings#cache)
* [`enable_introspection`](/handbook/settings#enable_introspection)
* [`request_strategies`](/handbook/settings#request_strategies)
* [`enable_string_collector`](/handbook/settings#enable_string_collector)
* [`default_response_format`](/handbook/settings#default_response_format)
* [`schema_type_names`](/handbook/settings#schema_type_names)
* [`default_subscription_provider`](/handbook/settings#default_subscription_provider)
* [`default_subscription_broadcastable`](/handbook/settings#default_subscription_broadcastable)

Here is the list of settings exclusive for the schemas:
* `subscription_provider`: The instance of the subscription provider setup manually. Default `nil`.

You can use the block approach or direct assignment to change the settings.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    # Direct access
    config.enable_string_collector = false

    # Block approach
    configure do |config|
      config.enable_string_collector = false
    end
  end
end
```

## Fields

The fields of a schema are divided into 3 groups: `query`, `mutation`, and `subscription`.
This gem does not require you to set up a type for each one of this collection of fields.
Schemas use a shared concept, which has a collection of methods and one instance variable
per each group.

Inside of your schema, you can easily add fields by just calling their supporting methods:

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    query_fields do
      field(:a_query, :string)
    end

    mutation_fields do
      field(:a_mutation, :string)
    end

    subscription_fields do
      field(:a_subscription, :string)
    end
  end
end
```

However, this gem provides several other ways for you to declare your fields. You should
use this only for the simplest things.

Read more about [fields](/guides/fields), [alternatives](/guides/alternatives),
and [field lists](/guides/field-lists).

## Dependencies

Dependencies are how you inform the Type Map that other files should be loaded
before a schema can be fully validated. There are 2 ways of informing dependencies,
plus 1 way of importing things into your schema.

{: .highlight }
> This is crucial for the organization of your application.

### Known Dependencies

Known dependencies are types provided by this or other gems that are not loaded by default.
Types that the Type Map doesn't know about will be treated as pure strings (and you will get
a warning about it).

Here is how you can load these dependencies:

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    # Inform the type and the names that should be loaded
    load_scalars :bigint, :date_time

    # OR
    load_dependencies :scalar, :bigint, :date_time
  end
end
```

The list of available dependencies can be found on [`config.known_dependencies`](/handbook/settings#known_dependencies).

### Local Dependencies

Local dependencies are other directories containing types necessary for the schema.
Different from Rails, GraphQL needs to know everything it has available.
Therefore, all its objects, types, and inputs must be loaded beforehand.
The explicit load was intentional.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    # Load one specific directory recursively
    load_directory 'objects'

    # Load only that directory non-recursively
    load_directory 'objects', recursive: false

    # Load more than one directory at once
    load_directory 'objects', 'inputs'

    # With no arguments, it will load the current directory recursively
    load_directory
    # Same as
    load_directory '.', recursive: true
    # OR
    load_current_directory
  end
end
```

Files will be loaded when a request is processed and the types involved
can't be found straightaway.

### Importing Fields

As mentioned before, schema fields can be defined in different ways.
When declared outside of the schema, they need to be properly imported into it.
One method imports a single field into a specific type, and the other imports
the whole module and all fields declared in it to their proper places.
These methods can be tuned to fit your needs.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    # Import a field declared as a class into this schema
    import_into :query, GraphQL::Queries::Sample

    # Import the whole module into the schema, non-recursively
    import_all GraphQL::Queries

    # Import the whole module into the schema recursively
    import_all GraphQL::Queries, recursive: true
  end
end
```

[Sources](/guides/sources) do not require importing because they have their
own mechanism for publishing their fields.

Read more about [alternatives](/guides/alternatives) and [importing fields](/guides/field-lists#importing).

## Subscriptions

Subscriptions will work with [ActionCable](/guides/subscriptions/action-cable-provider) provider and [Memory](/guides/subscriptions/memory-store) store by default. The methods provided in the schema
mostly work as a bridge between the requests and the provider configured.

What matters the most for the schema is the provider, and you can set up one using the config of the schema.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    # This is the default behavior when the config is left as nil
    config.subscription_provider =
      Rails::GraphQL::Subscription::Provider::ActionCable.new(
        cable: ::ActionCable,
        prefix: 'graphql',
        store: Rails::GraphQL::Subscription::Store::Memory.new,
        logger: GraphQL::AppSchema.logger,
      )
  end
end
```

Read more about [subscriptions providers](/guides/subscriptions#provider).

## Cache

The cache is crucial for schemas that deal with subscriptions.
Some other features also rely on the cache to improve performance and strictness of requests.
However, the methods provided for the schema are simply a bridge between the requests and the configured cache provider.
By default, the schema will rely on [`config.cache`](/handbook/settings#cache).

```ruby
# Schema methods available for caching
GraphQL::AppSchema.subscription_id_for(*)  # => SecureRandom.uuid
GraphQL::AppSchema.cached?(*)              # => config.cache.exist?(*)
GraphQL::AppSchema.delete_from_cache(*)    # => config.cache.delete(*)
GraphQL::AppSchema.read_from_cache(*)      # => config.cache.read(*)
GraphQL::AppSchema.write_on_cache(*)       # => config.cache.write(*)
GraphQL::AppSchema.fetch_from_cache(*)     # => config.cache.fetch(*)
```

As long as the `config.cache` object setup complies with
<a href="https://edgeapi.rubyonrails.org/classes/ActiveSupport/Cache/Store.html" target="_blank" rel="external nofollow">ActiveSupport Cache Store</a>,
you won't need to override these methods.

## Error Handling

Schemas implement
<a href="https://edgeapi.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html" target="_blank" rel="external nofollow">ActiveSupport::Rescuable</a>.
Therefore, for exception handling, it will behave as a controller.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    rescue_from ActiveRecord::RecordNotFound do |exception|
      # The message of the error
      exception.message.inspect

      # Likely the field of the error
      exception.source.inspect

      # The running request where the error occurred
      exception.request.inspect
    end
  end
end
```

By default, all the exceptions will be turned into proper errors in the response,
plus you will receive a nice backtrace display in your logs.

Read more about [request logs](/guides/request#logs).

## Inline Types

Inside your schema, you can quickly define types. There are some use cases that this can be
a good approach. However, it's recommended to break large schemas into several files and use
[local dependencies](#local-dependencies) instead.

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    enum 'Episode' do
      desc 'One of the films in the Star Wars Trilogy'

      add 'NEW_HOPE', desc: 'Released in 1977.'
      add 'EMPIRE',   desc: 'Released in 1980.'
      add 'JEDI',     desc: 'Released in 1983.'
    end

    object 'Human' do
      desc 'A humanoid creature in the Star Wars universe'

      field :id, null: false, desc: 'The id of the human'
      field :name, desc: 'The name of the human'
    end
  end
end
```

This is recommended only for really small schemas or for testing purposes. It can also be
used to demonstrate issues with the gem.

Read more about [inline types](/guides/advanced/types#inline-creation) and [recommendations](/guides/recommendations).

## Type Map Interaction

Schemas interacts with the Type Map to resolve the types within its components. It's pretty
much a shortcut, adding the namespace before fetching from the Type Map. However, it is the
recommended way of using it.

```ruby
GraphQL::AppSchema.find_type(:string)
GraphQL::AppSchema.find_type!(:string)
GraphQL::AppSchema.find_directive!('deprecated')
```

Regardless, this is something other than what you will be interacting.
In normal circumstances, fields will know how to solve their types through their schemas.

Read more about the [Type Map](/guides/type-map).

## Others

There are a couple of other methods available for schemas:

#### `to_gql`

Prints the whole schema and its structure in a formatted GraphQL syntax. Great for debugging.
See an example on the [controller](/guides/customizing/controller#describe).

#### `introspection?`

Checks if the current schema has introspection enabled.

#### `enable_introspection!`

Enable introspection for the current schema.

Read more about [introspection](/guides/introspection).
