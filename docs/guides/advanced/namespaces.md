---
layout: default
title: Namespaces - Advanced - Guides
description: Everything you need to know about working with multiple schemas and namespaces
---

# Namespaces

Namespaces allow you to have multiple schemas under the same application, making sure
they are isolated while also sharing common components.

Let's imagine a scenario where your application has an admin and a client side, and you want
to run both in GraphQL. But, the admin will have its set of queries, mutations,
and subscriptions, while the client side will have a different set. On top of that,
some common components should be available on both sides, so you don't have to repeat
the code.

Such a scenario is possible with the usage of namespaces.

## How it works

You just have to remember three things:

1. Schemas only refer to a single namespace;
1. Any other component can have multiple namespaces;
1. The `:base` namespace is the fallback.

With that in mind, the solution is to create two schemas, each one with its own
namespace. Then add isolated components to their respective namespace and the
shared ones to either the `:base` or to both namespaces.

## Setting the Namespace

There are two ways to define a component's namespace:

```ruby
# app/graphql/objects/user.rb
set_namespace :admin     # This forces the value
namespace :admin         # This adds to the list
```

You can call `.namespaces` from any component to see its value.

{: .note }
> **Note**
> Namespaces are inherited by default, but you can use the above methods
> to replace or increment the value.

## Module Association

To reduce the number of places you might have to set the namespace manually,
the [Type Map](/guides/type-map) allows you to associate a module to a namespace. When
doing this, any component inside of that method or its descendants will be automatically
set to that namespace unless told otherwise.

Here is how you can configure that:

```ruby
GraphQL.type_map.associate(:admin, GraphQL::Admin)
# OR
# app/graphql/admin_schema.rb
namespace :admin, GraphQL::Admin
```

The schema has its own version of the `namespace` method, which allows you to set the namespace
and, at the same time, associate a module to it.
