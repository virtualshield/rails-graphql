---
layout: default
title: Fields - Advanced - Guides
description: All about the advanced features of fields
---

# Fields

This page will explore more advanced features of [fields](/guides/fields).
It would be best if you started from there before reading this content.

## Equivalency

All fields and [types](/guides/advanced/equivalency) have an equivalency operator `=~`.
This operator helps to identify if the left side can be used as the right side. The equivalency takes
into consideration several different factors, and some specific types of fields have their own
extension of this operator. Here are some rules:

* Both types associated to the fields must be equivalent;
* Although the right field may have more arguments, all of the left field's arguments must
be present and equivalent to the ones in the right field's arguments;
* A not `null`-able left field is equivalent to a `null`-able right field.

## Event Sources

The [events](/guides/events) associated to a field may come from several different places.
Here is the list of the sources in their proper order of precedence:

1. Events from directives attached to the field;
1. Events from directives attached to the type of the field;
1. Events created using [`on`](/guides/events#using-events) or [shortcuts](/guides/events#shortcuts);

{: .highlight }
> **Soon**
> [Output fields](/guides/fields#output-fields) will be able to have [directives](/guides/directives) added
> to their [arguments](/guides/arguments), making it another source of events.

Read more about [request events](/guides/request#event-types).

## Metadata

{: .warning }
> **Unavailable**
> This feature is yet to be published.

Metadata is a simple `Hash` added to fields that may contain any additional information
you want to associate with them. See the example below for how to write and read values.

```ruby
# Writing
field(:name, meta: { counter: 1 })
# OR
field(:name) do
  metadata :counter, 1
end

# Reading
find_field(:name).metadata[:counter]
# OR, on an event
field.metadata[:counter]
```

## Proxies

Field proxies are the most advanced feature of this gem. You can think of it as a
selective multi-inheritance. Selective because not all properties are inherited and
multi because you can have proxies of proxies.

Proxied fields will have the same class as their source but with a series of
`Proxied` specific extensions. Each type and extension of a field can have its
own `Proxied` module that changes its behavior when working with a proxied field.

Due to proxies, you can define your GraphQL schema in no specific order,
and it will still produce consistent APIs. Plus, proxies were designed to work
with events, meaning that events from the proxy will be added at the end of the
list.

{: .important }
> Regular inheritance, [sources](/guides/sources),
> [importing fields](/guides/schemas#importing-fields),
> and [implementing interfaces](/guides/interfaces#importing-fields)
> will produce proxies.

### Creating

You can create a proxy of a field by adding a new field to any component
considered a [field list](/guides/field-lists#proxy). When you create a proxy,
you have a one-time opportunity to give it a different name by passing a second
argument or using either `:as` or `:alias` named arguments.

```ruby
proxy_field(GraphQL::User[:name])
# OR
proxy_field(GraphQL::User[:name], as: :user_name)
```

### Identifying

All fields have a `proxy?` method that will indicate whether it is a proxy.
You can also identify that a field is a proxy by checking the result of the
`inspect` of a field, for example:

{: .rails-console }
```ruby
:001 > GraphQL::AppSchema[:query][:users]
    => #... @source=GraphQL::UserSource[:users] [proxied] ...
```

### Type Resolution

One interesting thing about proxies is that they inherit the `type` setting, but not
the resolved `type_klass`. This was intentional, to allow proxies to be resolved
for more specific types.

For example, if you have two [namespaces](/guides/advanced/namespaces), you can
create a field with a `"User"` type. Then, when they are imported to their proper
schema, each one can be resolved to that schema's specific `User` type.

```ruby
# app/graphql/queries/user.rb
class GraphQL::Queries::User < GraphQL::Query
  returns 'User'
end

# app/graphql/admin_schema.rb
object('User') #        ↰ The type will be this object
add_proxy_field(:query, GraphQL::Queries::User)

# app/graphql/client_schema.rb
interface('User') #     ↰ The type will be this interface
add_proxy_field(:query, GraphQL::Queries::User)
```

### Properties

Here is a list of properties of a proxy field and their respective behavior:

`arguments`
: Concatenated

`array`
: Inherited

`authorizer`
: Changeable

`broadcastable`
: Changeable

`description`
: Changeable

`directives`
: Concatenated

`enabled`
: Changeable

`events`
: Concatenated

`full_scope`
: Concatenated

`gql_name`
: Changeable

`listeners`
: Concatenated

`metadata`
: Concatenated

`method_name`
: Changeable

`method_name`
: Changeable

`name`
: Changeable

`null`
: Inherited

`nullable`
: Inherited

`owner`
: Different

`performer`
: Changeable

`resolver`
: Changeable

`type_class`
: Variable

`type`
: Inherited

* **Changeable:**{: .text-red-100 } Value is inherited but can be changed in the proxy;
* **Concatenated:**{: .text-red-100 } Both values are combined to make it one;
* **Different:**{: .text-red-100 } It will always be different;
* **Inherited:**{: .text-red-100 } It will always be inherited;
* **Variable:**{: .text-red-100 } It may vary from the original.

### From Interfaces

Proxies created from [implementing interfaces](/guides/interfaces#importing-fields) have
a more restrictive list of things you are allowed to change. In such cases, you **cannot**
rename the field nor change its `enabled` status.
