---
layout: default
title: Names - Guides
description: Everything you need to know about how things are and should be named
---

# Names

This gem follows a strict pattern related to names. All paces will force the convention
so that you don't have to worry about it and make it feel as natural as possible.

## Rule of Thumb

Symbols are always `:snake_case` and refer to the Ruby name of things. Strings are `cameCase`
for [fields](/guides/fields), [arguments](/guides/arguments), and [directives](/guides/directives),
and `PascalCase` for [enums](/guides/enums), [inputs](/guides/inputs), [interfaces](/guides/interfaces),
[objects](/guides/objects), [scalars](/guides/scalars), [unions](/guides/unions), and [schemas](/guides/schemas)
and refer to the GraphQL name of things
(excepts for [type assignment](/guides/advanced/type-assignment)).

## What to use Where

Following the rules below will provide the best experience, code clarity, and consistency
with the design intended for this gem:

1. For field names, use symbols;
1. For scalar types, use symbols;
1. For any other type, use strings;
1. For directives, use the block approach with [`use`](/guides/fields#directives) and symbols;
1. **Never use constants (classes) to reference a type**{: .fw-900 }.

{: .important }
> **Important**
> [Enum values](/guides/enums#values) and [arguments](/guides/arguments) are the only
> places where you can't set up directives without using the classes directly.
> This will be addressed as directives get additional features.

Read more about [recommendations](/guides/recommendations).

## Special Names

GraphQL uses a `__` (double underscore) prefix for everything internal (fields, objects, and other things).
That said, you should avoid using the `__` prefix.

This gem uses a `_` (single underscore) prefix for its own internal things, so unless you are writing a gem to enhance
this gem, you should avoid it also.

Read more about [introspection](/guides/introspection) and [schema types](#schema-types).

## Accessing the Name

All elements mentioned in the [rule of thumb](#rule-of-thumb) will have a `gql_name`, which refers to their sanitized
GraphQL string name. All symbolized names (`name`) are also sanitized before they are ever used.
Here is an example:

{: .note }
> `gql_name` has a `graphql_name` alias, in case you want to be explicit about it.

```ruby
name_field = field(:FirstName, :string)
name_field.name                             # :first_name
name_field.gql_name                         # "firstName"
```

Classes also follow the same pattern. But, instead of `name`, which still returns the
name of the class, the `to_sym` will return its Ruby name. Plus, unnecessary suffixes
will be removed (except for [inputs](/guides/inputs), [see auto suffix](/handbook/settings#auto_suffix_input_objects)).

```ruby
class GraphQL::User < GraphQL::Object; end
GraphQL::User.to_sym                        # :user
GraphQL::User.gql_name                      # "User"

class GraphQL::PersonInterface < GraphQL::Interface; end
GraphQL::PersonInterface.to_sym             # :person
GraphQL::PersonInterface.gql_name           # "Person"

class GraphQL::RoleEnum < GraphQL::Scalar; end
GraphQL::RoleEnum.to_sym                    # :role_enum
GraphQL::RoleEnum.gql_name                  # "RoleEnum"

class GraphQL::Product < GraphQL::Input; end
GraphQL::Product.to_sym                     # :product_input
GraphQL::Product.gql_name                   # "ProductInput"

class GraphQL::UserInput < GraphQL::Input; end
GraphQL::UserInput.to_sym                   # :user_input
GraphQL::UserInput.gql_name                 # "UserInput"
```

Since you are already inside the `GraphQL` module, there is no reason to suffix your types.
However, you can keep an even closer pattern to Rails, based on the
[directory structure](/guides/architecture#directory-structure) and how folders should
dictate the suffix of the classes in them. Both ways are supported,
and the only recommendation is to choose one and stick with it forever.

{: .note }
> This docs follows the no-suffix pattern only to simplify things.

## Schema Types

The [fake types](/guides/field-lists#type-type-object) associated with the [schema fields](/guides/schemas#fields)
have a special name. They are prefixed with an `_` to indicate that they are somewhat
internal. This was inspired by GraphQL's internal field `__Type`. You can change their names
using the [`schema_type_names`](/handbook/settings#schema_type_names) setting.

```graphql
schema {
  query: _Query
  mutation: _Mutation
  subscription: _Subscription
}
```

There are 3 reasons why this patter was selected:
1. `_` communicates something similar to GraphQL's internal `__`;
1. It avoids collisions with a possible type `Subscription`;
1. It facilitates searching and identifying such types.
