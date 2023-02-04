---
layout: default
title: Type Map - Guides
description: Responsible for resolving types and keeping an index of everything available
---

# Type Map

The type map is central for most of the things that happen in this gem. Its purpose is to
keep track of everything that has been added to your application's GraphQL area and ensure
that components are properly accessible from their requested scope.

{: .note }
> **Note**
> This page explains how the Type Map works, but you don't need to know this to use the gem.

You can think about the Type Map as the central index of all the things defined for GraphQL.
This index is also versioned, which means that cached resources should be invalidated if
the Type Map has a different version than when the value was cached.

The Type Map index is composed of three parts:

`namespace`
: The [namespace](/guides/advanced/namespaces) of the element

`base_class`
: One of `Type`, `Directive`, `Schema`

`key`
: The key of the element

```ruby
Rails::GraphQL.type_map.fetch!(
  :string,               # key
  base_class: :Type,     # base_class
  namespace: :base,      # namespace
)
```

{: .highlight }
> The Type Map architecture was based on
> <a href="https://github.com/rails/rails/blob/main/activerecord/lib/active_record/type/type_map.rb" target="_blank" rel="external nofollow">ActiveRecord::Type::TypeMap</a>.

## Registering

The registration process only happens when the index is consulted. Before that, components are
added to a `postponed` registration, which happens when you inherit one of the GraphQL classes.
They are postponed because changes may occur after the class is inherited, and those changes
can affect registration.

Here is how you can check how many postponed objects are waiting to be registered:

{: .rails-console }
```ruby
:001 > Rails::GraphQL.type_map.inspect
    => #<Rails::GraphQL::TypeMap [index] ... @pending=3 ...>
```

When components are actually registered, all its namespaces, name, and possible aliases are
added to the index. However, only one item actually points to the components, the others
just simply points to that other value. This is how it works

```ruby
@index[:base][:Type][:string] = Rails::GraphQL::Type::Scalar::StringScalar
@index[:base][:Type]['String'] = -> { @index[:base][:Type][:string] }
```

## Aliases

At any time, you can add aliases to types. You have two options, an alias to another key or
a resolution block that should be called when the alias key is requested. This is widely
used to map database-specific types to GraphQL types.

```ruby
Rails::GraphQL.type_map.register_alias(:str, :string)
# OR
Rails::GraphQL.type_map.register_alias(:str) do
  Rails::GraphQL::Type::Scalar::StringScalar
end
```

Read more about [ActiveRecord source](/guides/sources/active-record)

## Un-registering

Due to the Rails reloader, the Type Map must know how to unregister objects from its index.
However, the process is quite simple because we can only assign a `nil` value to the
outermost item of the index.

```ruby
# This will guarantee a proper cleanup of the schema
Rails::GraphQL.type_map.unregister(GraphQL::AppSchema)
```

## Register Hook

The Type Map allows you to add a hook for when an expected key is created. This allows you to
conditionally add fields and other components to objects requiring another to exist first.
The block will only be called when the `namespace` and the `base_class` match the ones
provided to the hook setup. The block will be called immediately if a key matching
this criteria already exists.

```ruby
# This will be added as a hook
Rails::GraphQL.type_map.after_register(:str) do |object|
  puts object.name     # Rails::GraphQL::Type::Scalar::StringScalar
end

# This will trigger the above hook
Rails::GraphQL.type_map.register_alias(:str, :string)

# This will now be triggered immediately
Rails::GraphQL.type_map.after_register(:str) do |object|
  puts object.name     # Rails::GraphQL::Type::Scalar::StringScalar
end
```

## Fetching

You have two options when fetching keys from the Type Map: `fetch` and `fetch!`.
The biggest difference between them is that the second one will load
dependencies after a first try, warn about the usage of a fallback, or
raise a [`NotFoundError`](/handbook/exceptions#notfounderror) if unable to resolve the key.
They both will register all pending components before attempting to fetch.

{: .rails-console }
```ruby
:001 > Rails::GraphQL.type_map.fetch(:str)
    => nil
:002 > Rails::GraphQL.type_map.fetch!(:str)
    => # Unable to find :str Type object. (Rails::GraphQL::NotFoundError)
:002 > Rails::GraphQL.type_map.fetch!(:str, fallback: :string)
    => # [GraphQL] Type "str" is not defined, using String instead.
       #<GraphQL::Scalar String>
```

## Reading

There are two ways you can read what Type Map has registered:

{: .no_toc }
#### `objects(base_classes: nil, namespaces: nil)`

Get the list of all objects given one or many `base_classes` and `namespaces`.

{: .no_toc }
#### `each_from(namespaces, exclusive: false, base_classes: nil) {}`

Iterate over the objects from the given `namespaces` and `base_classes`.
The `exclusive` argument prevents the `:base` namespace from automatically being
considered.
