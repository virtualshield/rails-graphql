---
layout: default
title: Abstract - Advanced - Guides
description: All about abstract components
---

# Abstract

Most of the GraphQL components of this gem can be marked as `abstract`, which
indicates that such components must be inherited first before being used.

There are two main reasons why to mark a component as abstract:

1. They are not registered to the [Type Map](/guides/type-map);
1. They can't be instantiated directly during [events](/guides/events).

This feature is recommended for those that wish to create other gems based on
this one.

{: .important }
> **Important**
> This feature is under review, which means it may behave differently
> than described in some situations.

## How to Use It

To mark a component as abstract, you can simply:

```ruby
# app/graphql/objects/base_object.rb
self.abstract = true
```

You use of this to add shared methods, set configurations like
[namespaces](/guides/advanced/namespaces), and create intermediate steps
for [sources](/guides/sources/#hooks).
