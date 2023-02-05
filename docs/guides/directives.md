---
layout: default
title: Directives - Guides
description: All you need to know about how to work with directives
---

# Directives

```graphql
@deprecated(reason: 'This is just an example')
```

Directives are part of the
<a href="http://spec.graphql.org/October2021/#sec-Type-System.Directives" target="_blank" rel="external nofollow">GraphQL spec</a>
and the recommended way to extend GraphQL's behaviors.

In this gem, directives are fully event-driven. The idea is to explore the [events](/guides/events)
as much as possible, for both definition and execution scopes, to create an ecosystem of
shareable features. Several decisions were made to provide the right environment for
directives.

## Creating a Directive

You can create your own directive by simply extending the `GraphQL::Directive` class. As long
as the file is [properly loaded](/guides/schemas#local-dependencies) or
[added as a dependency](/handbook/settings#known_dependencies), it will be added to
the [Type Map](/guides/type-map) and ready to use.

```ruby
# app/graphql/directives/awesome_directive.rb
module GraphQL
  class AwesomeDirective < GraphQL::Directive
    placed_on :object

    on(:attach) do |source|
      puts "I've been added to #{source.name}"
    end
  end
end
```

Whenever an object requires using this directive, the `:attach` event will be triggered, and
you will be able to access several things from the event and manipulate the object it
was attached to.

Read more about [events](/guides/events).

### Description

Allows documenting directives. This value can be retrieved using [introspection](/guides/introspection)
or during a [to_gql](/guides/customizing/controller#describe) output. Within the class, `desc`
works as a syntax sugar for `self.description = ''`. It also supports descriptions from I18n.

```ruby
# app/graphql/directives/awesome_directive.rb
module GraphQL
  class AwesomeDirective < GraphQL::Directive
    desc 'This is awesome!'
  end
end
```

### Repeatability

By default, directives must be unique when applied to anything. However, you can change that
behavior by marking that your directive can be repeated in a given location.

```ruby
# app/graphql/directives/awesome_directive.rb
self.repeatable = true
```

### Arguments

Arguments can help you control what exactly the directive should do. Definition-based directives
can use arguments during the `:attach` event, and execution-based directives can use during any of
the events of a request.

```ruby
# app/graphql/directives/awesome_directive.rb
argument :name, :string, null: false

on(:attach) do |source, name:|
  puts "I've been added to #{source.name}, that provided #{name}"
end
```

Read more about [arguments](/guides/arguments), [events](/guides/events),
and [request](/guides/request#events).

### Restrictions

All directives must have `locations` where they can be used. You must call `placed_on` with
the list of acceptable locations.

```ruby
# app/graphql/directives/awesome_directive.rb
placed_on :object
```

When creating a directive that will affect the definition of you GraphQL schema, use one or
more fo these options:

`:schema`
: Applies to [Schemas](/guides/schemas)

`:scalar`
: Applies to [Scalars](/guides/scalars)

`:object`
: Applies to [Objects](/guides/objects)

`:field_definition`
: Applies to any [Output Fields](/guides/fields#output-fields)

`:argument_definition`
: Applies to any [Arguments](/guides/arguments)

`:interface`
: Applies to [Interfaces](/guides/interfaces)

`:union`
: Applies to [Unions](/guides/unions)

`:enum`
: Applies to [Enums](/guides/enums)

`:enum_value`
: Applies to a value of an [Enum](/guides/enums#values)

`:input_object`
: Applies to [Inputs](/guides/inputs)

`:input_field_definition`
: Applies to any [Input Fields](/guides/fields#input-fields)

When creating a directive that will affect the execution of your GraphQL documents, use one or
more fo these options:

`:query`
: Applies to [Queries](/guides/queries)

`:mutation`
: Applies to [Mutations](/guides/mutations)

`:subscription`
: Applies to [Subscriptions](/guides/subscriptions)

`:field`
: Applies to any [Output Field](/guides/fields#output-fields)

`:fragment_definition`
: Applies to [Fragments](/guides/fragments)

`:fragment_spread`
: Applies to [Spreads for Fragments](/guides/spreads#fragment)

`:inline_fragment`
: Applies to [Inline Spreads](/guides/spreads#inline)

## Using Directives

### Definitions

To use directives on the definitions of your schema, you can call `use` to set up a new
directive or append a new directive instance to that class.

```ruby
# This will set up a new instance
use :awesome, name: 'User'

# This will append the instance
use GraphQL::AwesomeDirective.new(name: 'User')

# This is the same as the above
use GraphQL::AwesomeDirective(name: 'User')
```

As a recommendation, it is always better **not** to reference the classes directly, so
the first approach is preferable.

Read more about [recommendations](/guides/recommendations).

### Executions

To use directives on the execution of your requests, you can use the `@` syntax to
add it where you want to use it.

```graphql
query($public: Boolean!) {
  user {
    id @skip(if: $public)
    name
  }
}
```

## Available Directives

{: .important }
> Several other directives are already planned to be added to this gem.

Here is a list of all available directives in this gem:

### From the Spec

#### `@deprecated`

Indicate deprecated portions of a GraphQL service's schema, such as deprecated
fields or deprecated enum values.

`placed_on:`
: `:field_definition`, `:enum_value`

`repeatable`
: `false`

Arguments
: <span></span>

`reason: String`
: Explain why the underlying element was marked as deprecated. If possible,
indicate what element should be used instead. This description is formatted
using Markdown syntax (as specified by
<a href="http://commonmark.org/" target="_blank" rel="external nofollow">CommonMark</a>).

```ruby
use :deprecated, reason: 'Too old'
```

{: .note }
> [Fields](/guides/fields) and [enum values](/guides/enums#values) provide an additional
> setting called `:deprecated` that works as a shortcut to add a deprecated directive to them.

This directive works as a simple warning. When used, everything queried that returns
deprecated elements get an error message, as in:

```json
{
  "data": {
    "username": "john.doe"
  },
  "errors": [
    {
      "message": "The username field is deprecated, reason: Too old."
    }
  ]
}
```

#### `@include`

Allows for conditional inclusion during execution as described by the if argument.

`placed_on:`
: `:field`, `:fragment_spread`, `:inline_fragment`

`repeatable`
: `false`

Arguments
: <span></span>

`if: Boolean!`
: When false, the underlying element will be automatically marked as null.

```graphql
query($private: Boolean!) {
  user {
    id @include(if: $private)
    name
  }
}
```

When `if` is `true`:

```json
{ "data": { "user": { "id": "1", "name": "John Doe" } } }
```

When `if` is `false`:

```json
{ "data": { "user": { "name": "John Doe" } } }
```

#### `@skip`

Allows for conditional exclusion during execution as described by the if argument.

`placed_on:`
: `:field`, `:fragment_spread`, `:inline_fragment`

`repeatable`
: `false`

Arguments
: <span></span>

`if: Boolean!`
: When true, the underlying element will be automatically marked as null.

```graphql
query($public: Boolean!) {
  user {
    id @skip(if: $public)
    name
  }
}
```

When `if` is `true`:

```json
{ "data": { "user": { "name": "John Doe" } } }
```

When `if` is `false`:

```json
{ "data": { "user": { "id": "1", "name": "John Doe" } } }
```

#### `@specifiedBy`

A built-in directive used within the type system definition language to provide
a scalar specification URL for specifying the behavior of custom scalar types.

`placed_on:`
: `:scalar`

`repeatable`
: `false`

Arguments
: <span></span>

`url: String!`
: Point to a human-readable specification of the data format.

```ruby
use :specified_by, url: 'https://www.rfc-editor.org/rfc/rfc3339'
```

This directive has no effect whatsoever, and its only purpose is to be displayed in
the [introspection](/guides/introspection) or during a [to_gql](/guides/customizing/controller#describe) output.
