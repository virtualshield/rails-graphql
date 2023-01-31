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

These fields are added to the `query_fields` of your [schema](/guides/schema).

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

Displays the information about a [directive](/guides/directive).

`name`
: `String!`, the GraphQL name

`description`
: `String`, the description

`locations`
: [`[__DirectiveLocation!]!`](#__directivelocation), the [locations](/guides/directives#restrictions)
where the directive can be applied

`args`
: [`[__InputValue!]!`](#__inputvalue), the list of arguments accepted by the directive

`isRepeatable`
: `Boolean!`, indicates if the directive can be repeated

#### `__EnumValue`

Displays the information about an [enum value](/guides/enums#values).

`name`
: `String!`, the GraphQL name

`description`
: `String`, the description

`isDeprecated`
: `Boolean!`, indicates if the value is deprecated

`deprecationReason`
: `String`, the reason added to the deprecated directive, if any

#### `__Field`

Displays the information about an [output field](/guides/fields#output-fields).

`name`
: `String!`, the GraphQL name

`description`
: `String`, the description

`args`
: [`[__InputValue!]!`](#__inputvalue), the list of arguments accepted by the field

`type`
: [`__Type!`](#__type), the return type

`isDeprecated`
: `Boolean!`, indicates if the field is deprecated

`deprecationReason`
: `String`, the reason added to the deprecated directive, if any

#### `__InputValue`

Displays the information about an [argument](/guides/arguments) or [input field](/guides/fields#input-fields).

`name`
: `String!`, the GraphQL name

`description`
: `String`, the description

`type`
: [`__Type!`](#__type), the accepted type

`defaultValue`
: `String`, the default value formatted as JSON string

#### `__Schema`

Displays the information about a [schema](/guides/schemas).

`types`
: [`[__Type!]!`](#__type), all its known types

`queryType`
: [`__Type!`](#__type), the object with the query fields

`mutationType`
: [`__Type`](#__type), the object with the mutation fields

`subscriptionType`
: [`__Type`](#__type), the object with the subscription fields

`directives`
: [`[__Directive!]!`](#__directive), all its known directives

#### `__Type`

Displays the information about a type
([enums](/guides/enums), [inputs](/guides/inputs), [interfaces](/guides/interfaces),
[objects](/guides/objects), [scalars](/guides/scalars), and [unions](/guides/unions)).

`kind`
: [`__TypeKind!`](#__typekind), which kind of type

`name`
: `String!`, the GraphQL name

`description`
: `String`, the description

`specifiedByURL`
: `String`, the specification url<br/>(only for scalars)

`fields`
: [`[__Field!]`](#__field), the list of output fields<br/>(only for objects and interfaces)

`interfaces`
: [`[__Type!]`](#__field), the list of implemented interfaces<br/>(only for objects)

`possibleTypes`
: [`[__Type!]`](#__type), the possible object types<br/>(only for interfaces and unions)

`enumValues`
: [`[__EnumValue!]`](#__enumvalue), the list of enum values<br/>(only for enums)

`inputFields`
: [`[__InputValue!]`](#__inputvalue), the list of input fields<br/>(only for inputs)

`ofType`
: [`__Type`](#__type), the underlying type

#### `List`

A simple object to represent that a type is a list of another type, as in `[String]`.

`kind`
: [`__TypeKind!`](#__typekind), `LIST`

`name`
: `String!`, `List`

`ofType`
: [`__Type`](#__type), the underlying type

#### `Non-Null`

A simple object to represent that a type won't be null, as in `String!`.

`kind`
: [`__TypeKind!`](#__typekind), `NON_NULL`

`name`
: `String!`, `Non-Null`

`ofType`
: [`__Type`](#__type), the underlying type

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
