---
layout: default
title: Types - Advanced - Guides
description: All you need to know about working it types
---

# Types

This gem provides all 6 GraphQL types: [enums](/guides/enums), [inputs](/guides/inputs),
[interfaces](/guides/interfaces), [objects](/guides/objects), [scalars](/guides/scalars),
and [unions](/guides/unions), and they all inherit from the same base `Type` class.
This base class helps to maintain common information about its children's classes.

Here is all the information you can get from them:

## Base type

The `base_type` returns the top-most class of the type, ignoring the `Type` class.

## Kind

The `kind` returns a symbol that indicates the kind of the type, which is one
of the first 6 of [this list](/guides/introspection#__typekind) in snake case.

## Kind Enum

Same as above, but returning the string value instead.

## Indicators

* The `abstract?` checks if the type is marked as [abstract](/guides/advanced/abstract).
* The `hidden?` checks if the type is marked as [hidden](#hidden).
* The `input_type?` checks if the type can be used as an input;
* The `output_type?` checks if the type can be used as an output;
* The `leaf_type?` checks if the type is a leaf ([enum](/guides/enums) or [scalar](/guides/scalars));
* The `operational?` checks if it is a fake type like `_Query`.

## Hidden

The hidden setting allow you to use types and [directives](/guides/directives) that will never
be exposed to a [request](/guides/request). It enables you to use the GraphQL structure
to meta-configure itself, like with [authorization](/guides/advanced/authorization).

```ruby
# app/graphql/enums/roles.rb
self.hidden = true
```

Beware even if a type is marked as hidden, it will still be published to the [Type Map](/guides/type-map),
which may cause unexpected overrides. To avoid that, use an isolated [namespace](/guides/advanced/namespaces).

## Metadata

{: .warning }
> **Unavailable**
> This feature is yet to be published.

Metadata is a simple `Hash` added to types that may contain any additional information
you want to associate with them. See the example below for how to write and read values.

```ruby
# Writing
metadata :counter, 1

# Reading
GraphQL::User.metadata[:counter]
```

## Equivalency

All types and [fields](/guides/advanced/fields#equivalency) have an equivalency operator `=~`.
This operator helps to identify if the left side can be used as the right side. The equivalency takes
into consideration several different factors, and each type has its own extension of this
operator. For example:

* An [object](/guides/objects) is equivalent to an [interface](/guides/interfaces),
if it implements that interface;
* An [object](/guides/objects) is equivalent to a [union](/guides/unions),
if it is a member of that union;
* The `float` scalar is equivalent to the `time` scalar because the latter inherits from the
former.

## Inline Creation

Schemas allow types to be created "inline", meaning they won't have a file of their own.
When types are created this way, their constant is added to a `NestedTypes` module from where
the creation started.

Types created inline can almost be fully configured using named arguments. But, you can
always pass a block and add things as if inside their classes.

{: .note }
> This requires further implementations and documentation as well.

Although this is not recommended, it can be handy in cases where you just need to simply
define an [union](/guides/unions) or an [enum](/guides/enums).

```ruby
# app/graphql/app_schema.rb
union 'Person', of_types: %w[User Admin]

enum 'Role', values: %i[admin support]
```

Read mode about [inline types](/guides/schemas#inline-types).
