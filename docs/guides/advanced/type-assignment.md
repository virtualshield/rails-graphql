---
layout: default
title: Type Assignment - Advanced - Guides
description: Assign other classes to types to gain extra powers
---

# Type Assignment

Types like [inputs](/guide/inputs), [interfaces](/guide/interfaces), [objects](/guide/objects),
and [sources](/guide/sources) can be assigned to other classes. This assignment means that
the GraphQL component is directly associated with that other class, and they will cooperate
in providing a smooth interaction.

## Setting It

You can simply set an assignment as following:

```ruby
# app/graphql/sources/admin_source.rb
class GraphQL::AdminSource < GraphQL::ARSource
  self.assigned_to = 'AdminUser'
```

It is recommended to always assign to the name of the class, so you don't generate
unnecessary loading of constants.

Read more about [recommendations](/guides/recommendations).

## How it Works

Whenever the GraphQL component needs to check if it is interacting with a value, it will
first check if the value is from the `assigned_class`.

Some classes, like [sources](/guide/sources), also guarantee that the assigned class
is based on another class to ensure its features are compatible.

## Type Map

Another interesting thing the assignment does is add an alias to the Type Map
for that class to the proper key to find the underlying GraphQL component. That means:

{: .rails-console }
```ruby
:001 > Rails::GraphQL.type_map.fetch(User)
    => #<GraphQL::Object User ...
```
