---
layout: default
title: Introspection - Guides
description: The way to find everything your schema has
---

# Introspection

Introspection is the combination of [fields](#fields), [objects](#objects), and
[enums](#enums) that exist to describe everything your schema has. Several other
libraries use the introspection of a schema to
<a href="https://the-guild.dev/graphql/codegen" target="_blank" rel="external nofollow">generate more code</a>
or to provide
<a href="https://github.com/graphql/graphiql" target="_blank" rel="external nofollow">autocompletion</a>,
for example.

## Enabling

There are three ways to enable introspection:

1. Using the [`enable_introspection`](/handbook/settings#enable_introspection) setting;
1. Using the [schema's configuration](/guides/schemas#configuring);
1. Or calling `enable_introspection!` in your schema.

```ruby
# app/graphql/app_schema.rb
config.enable_introspection = !Rails.env.production?
```

{: .warning }
> **Dangerous**
> You should always disable introspection in a **production**{: .fw-900 } environment. Otherwise, malicious
> users can exploit it and misuse your application.

## The Query

This is the common query used by libraries and other services based on GraphQL to collect
all the information they need:

{% include introspection-query.html %}

## The Components

To deliver such result, several elements are added to your schema.

### Fields

These fields are added to the `query_fields` of your [schema](/guides/schemas).

{: title="__schema" }
#### `__schema: __Schema!`

It resolves to the schema of the request, and returns a [`__Schema`](#__schema) type.

{: title="__type" }
#### `__type(name: String!): __Type`

It looks for a type with the given `name`. If it finds one from the [Type Map](/guides/type-map),
it returns a [`__Type`](#__type) type.

### Objects

These objects (and respective fields) are added to your schema.

#### `__Directive`

Displays the information about a [directive](/guides/directives).

`name`
: `String!` - Its GraphQL name

`description`
: `String` - The description

`locations`
: [`[__DirectiveLocation!]!`](#__directivelocation) - The [locations](/guides/directives#restrictions)
where the directive can be applied

`args`
: [`[__InputValue!]!`](#__inputvalue) - The list of arguments accepted by the directive

`isRepeatable`
: `Boolean!` - Indicates if the directive can be repeated

#### `__EnumValue`

Displays the information about an [enum value](/guides/enums#values).

`name`
: `String!` - The GraphQL name

`description`
: `String` - The description

`isDeprecated`
: `Boolean!` - indicates if the value is deprecated

`deprecationReason`
: `String` - The reason added to the deprecated directive - if any

#### `__Field`

Displays the information about an [output field](/guides/fields#output-fields).

`name`
: `String!` - The GraphQL name

`description`
: `String` - The description

`args`
: [`[__InputValue!]!`](#__inputvalue) - The list of arguments accepted by the field

`type`
: [`__Type!`](#__type) - The return type

`isDeprecated`
: `Boolean!` - Indicates if the field is deprecated

`deprecationReason`
: `String` - The reason added to the deprecated directive, if any

#### `__InputValue`

Displays the information about an [argument](/guides/arguments) or [input field](/guides/fields#input-fields).

`name`
: `String!` - The GraphQL name

`description`
: `String` - The description

`type`
: [`__Type!`](#__type) - The accepted type

`defaultValue`
: `String` - The default value formatted as JSON string

#### `__Schema`

Displays the information about a [schema](/guides/schemas).

`types`
: [`[__Type!]!`](#__type) - All its known types

`queryType`
: [`__Type!`](#__type) - The object with the query fields

`mutationType`
: [`__Type`](#__type) - The object with the mutation fields

`subscriptionType`
: [`__Type`](#__type) - The object with the subscription fields

`directives`
: [`[__Directive!]!`](#__directive) - All its known directives

#### `__Type`

Displays the information about a type
([enums](/guides/enums), [inputs](/guides/inputs), [interfaces](/guides/interfaces),
[objects](/guides/objects), [scalars](/guides/scalars), and [unions](/guides/unions)).

`kind`
: [`__TypeKind!`](#__typekind) - Which kind of type

`name`
: `String!` - The GraphQL name

`description`
: `String` - The description

`specifiedByURL`
: `String` - The specification url<br/>(only for scalars)

`fields`
: [`[__Field!]`](#__field) - The list of output fields<br/>(only for objects and interfaces)

`interfaces`
: [`[__Type!]`](#__field) - The list of implemented interfaces<br/>(only for objects)

`possibleTypes`
: [`[__Type!]`](#__type) - The possible object types<br/>(only for interfaces and unions)

`enumValues`
: [`[__EnumValue!]`](#__enumvalue) - The list of enum values<br/>(only for enums)

`inputFields`
: [`[__InputValue!]`](#__inputvalue) - The list of input fields<br/>(only for inputs)

`ofType`
: [`__Type`](#__type) - The underlying type

#### `List`

A simple object to represent that a type is a list of another type, as in `[String]`.

`kind`
: [`__TypeKind!`](#__typekind) - `LIST`

`name`
: `String!` - `List`

`ofType`
: [`__Type`](#__type) - The underlying type

#### `Non-Null`

A simple object to represent that a type won't be null, as in `String!`.

`kind`
: [`__TypeKind!`](#__typekind) - `NON_NULL`

`name`
: `String!` - `Non-Null`

`ofType`
: [`__Type`](#__type) - The underlying type

{: .important }
> These last two objects are not added to the [Type Map](/guides/type-map) because
> their sole purpose is to allow the `ofType` navigation.

### Enums

These enums (and respective values) are added to your schema.

#### `__DirectiveLocation`

The valid locations that a directive may be placed.

`QUERY`, `MUTATION`, `SUBSCRIPTION`, `FIELD`, `FRAGMENT_DEFINITION`, `FRAGMENT_SPREAD`,
`INLINE_FRAGMENT`, `SCHEMA`, `SCALAR`, `OBJECT`, `FIELD_DEFINITION`, `ARGUMENT_DEFINITION`,
`INTERFACE`, `UNION`, `ENUM`, `ENUM_VALUE`, `INPUT_OBJECT`, `INPUT_FIELD_DEFINITION`

#### `__TypeKind`

The fundamental unit of any GraphQL Schema is the type.
This enum enlist all the valid base types.

`SCALAR`, `OBJECT`, `INTERFACE`, `UNION`, `ENUM`, `INPUT_OBJECT`, `LIST`, `NON_NULL`

## Schema Example

Here is an example of a GraphQL schema that only includes the introspection elements:

{% include introspection-schema.html %}

{: .note }
> You can get a similar result from your [to_gql](/guides/customizing/controller#describe) output.
