---
layout: default
title: Fragments - Guides
description: Sharing common parts of your document
---

# Spreads

```graphql
...Profile             # Fragment spread
... on Profile { }     # Inline typed spread
... { }                # Inline type-less spread
```

Spreads allow you to request a specific set of fields in your document. Such a list of fields
can either be determined in-place (inline spread) or through a [Fragment](/guides/fragments).

## Using Spreads

Each type of spread has its purpose and utility.

### Fragment

This is the simplest form of a spread. It tells the request that, at that given
point, it should include the referenced Fragment's selection set into the response, just
like a reference to more fields.

It is mostly used to share common parts, and even recursive parts, of your document,
without having to repeat yourself. Plus, it's a great way to do
[componentization](/guides/fragments#components-and-fragments).

```graphql
query {
  me { ...Profile }
}

fragment Profile on User { picture name }
```

Read more about [Fragments](/guides/fragments).

### Inline

#### With a Type

Inline typed spreads will only add their selection set when the underlying data type
matches the type that is its own type. That means that only when [`__typename`](/guides/requests#typename)
and the referenced type in the spread are equal will it add its selection set to the response.

This is commonly used when dealing with [Interfaces](/guides/interfaces) and [Unions](/guides/unions)
since the actual type being added to the response is guaranteed to be an object type,
not these altered types.

```graphql
query {
  # Assuming me returns an interface
  me {
    email
    ... on User { slug }
    ... on Admin { role }
  }
}
```

#### Without a Type

This type of spread is inferred to be working with the same type as its parent. The main
reason why this is a valid way of using a spread is because spreads can be enhanced with
[directives](/guides/directives). Once enhanced by a directive, the selection set can
behave in specific ways.

This is really useful when used with directives like [`@include`](/guides/directives#include)
and [`@skip`](/guides/directives#skip), or as an alternative to the [componentization](/guides/fragments#components-and-fragments)
approach.

```graphql
query($profile: Boolean!) {
  me {
    ... @include(if: $profile) { picture name }
  }
}
```

```js
import Profile, { Fields as ProfileFields } from '@/components/profile';

const query = `query { me { ... ${ProfileFields} } }`;
```
