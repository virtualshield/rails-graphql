---
layout: default
title: Fragments - Guides
description: Sharing common parts of your document
---

# Fragments

```graphql
fragment Profile on User {
  picture
  name
}
```

Fragments are used in your [requests](/guides/requests) to reduce the number of times you need to repeat
a portion of the [selection set](/guides/request#selection-set), as well as a great
way to isolate the needs of your components.

## Using Fragments

You can use fragments in any part of your selection set, regardless of the type of the
[entry points](/guides/request#entry-points). The only thing that you need to do to use a fragment
is:

1. Ensure it has a unique name within the document of the request.
2. Has a type, and the fields selected are all present in that type.

The fragment type can be either an [Object](/guides/objects), an [Interface](/guides/interfaces),
or a [Union](/guides/unions) type.

```graphql
query {
  me { ...Profile }
}

fragment Profile on User { picture name }
```

The above quite the same as:

```graphql
query {
  me { picture name }
}
```

Read more about [spreads](/guides/spreads).

## Components and Fragments

As a recommendation, the components in your front end application should know
what fields they need to be rendered correctly. You can use that to turn that information
into fragments. Then, when the pages of your application perform GraphQL requests, you can
simplify the queries.

```js
// I want to show my profile and the profile of my friends
// where Profile is a separated component of my application
import Profile, { Fragment as ProfileFragment } from '@/components/profile';

const query = `
  query {
    me { ...Profile friends { ...Profile } }
  }

  ${ProfileFragment}
`;
```

The best part of this approach is that even if you need a composition of several
components on a given page, and some of them require similar sets of fields, the
result of your query will always add the field once. See the example:

```graphql
query {
  me { id ...Profile ...PersonalCard ...Recipient }
}

fragment Profile on User { picture name }
fragment PersonalCard on User { id name phone email }
fragment Recipient on User { id picture name email }
```

```json
{
  "data": {
    "me": {
      "id": "1",
      "picture": "avatar.jpg",
      "name": "John Doe",
      "phone": "+15551239876",
      "email": "john+doe@test.com"
    }
  }
}
```
